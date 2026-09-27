#!/bin/bash
# Test workstation: simulate the VMs in disposable Ubuntu/systemd containers.
# Generated credentials and installed services remain inside the test containers.
# The Docker kernel is shared: cleanup restores vm.max_map_count after container removal.
# Local integration tests: real Ubuntu packages and services, no host Docker socket.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
# Keep the all target sequential to limit memory/disk usage and kernel parameter changes.
target=${1:-lint}
if [[ $target == all ]]; then
    for service in lint failures nexus gitlab defectdojo sonarqube; do
        bash "$0" "$service"
    done
    exit 0
fi
case $target in lint|failures|nexus|gitlab|defectdojo|sonarqube) ;; *) echo "Usage: $0 [lint|failures|nexus|gitlab|defectdojo|sonarqube|all]" >&2; exit 1 ;; esac
# TEST_PLATFORM selects the test architecture, not the production VMs' architecture.
# Normalize Docker's architecture names to OCI platforms amd64/arm64.
platform=${TEST_PLATFORM:-linux/$(docker info --format '{{.Architecture}}')}
platform=${platform/aarch64/arm64}
platform=${platform/x86_64/amd64}
image=ossf-test-ubuntu:26.04-${platform##*/}
docker build --platform "$platform" -t "$image" "$root/tests/docker"
# lint reads the repository without write access, privileged containers or systemd startup.
if [[ $target == lint ]]; then
    docker run --rm --platform "$platform" --label ossf.test=true \
        -v "$root:/workspace:ro" "$image" bash /workspace/tests/docker/check-cli.sh
    exit 0
fi

name=ossf-test-$target-$$
# TEST_LOG_DIR is a path on the test workstation; logs must not contain secrets.
log_dir=${TEST_LOG_DIR:-${TMPDIR:-/tmp}/ossf-tests-$(date +%Y%m%d-%H%M%S)-$$}/$target
mkdir -p "$log_dir"
# Capture this for every service: GitLab package scripts also modify this limit.
original_map_count=$(docker run --rm --platform "$platform" --label ossf.test=true "$image" sysctl -n vm.max_map_count)
completed=0
# Preserve the test status and extract logs even after a failure.
# TEST_KEEP_CONTAINER=1 retains the instance for diagnosis and defers kernel cleanup.
cleanup() {
    local code=$?
    trap - EXIT
    # Bash 3.2 can enter an EXIT trap with status 0 after an expansion error.
    if [[ $completed != 1 && $code == 0 ]]; then code=1; fi
    docker cp "$name:/var/log/ossf-install.log" "$log_dir/install.log" 2>/dev/null || true
    docker cp "$name:/var/log/ossf-rerun.log" "$log_dir/rerun.log" 2>/dev/null || true
    if [[ ${TEST_KEEP_CONTAINER:-0} == 1 ]]; then
        echo "Container retained: $name"
    else
        docker rm -fv "$name" >/dev/null
        # Package maintainer scripts can also modify this shared kernel setting.
        # Restore after removal, so no remaining application can change it again.
        if [[ -n $original_map_count ]]; then
            docker run --rm --privileged --platform "$platform" --label ossf.test=true \
                "$image" sysctl -w "vm.max_map_count=$original_map_count" >/dev/null
        fi
    fi
    echo "Logs: $log_dir"
    exit "$code"
}
# systemd requires privileges, cgroups and temporary /run mounts here; no host ports/socket shared.
docker run -d --name "$name" --label ossf.test=true --platform "$platform" \
    --privileged --cgroupns private --shm-size 256m \
    --tmpfs /run --tmpfs /run/lock --tmpfs /tmp "$image" >/dev/null
trap cleanup EXIT
deadline=$((SECONDS + 60))
until docker exec "$name" systemctl is-system-running --quiet 2>/dev/null; do
    if (( SECONDS >= deadline )); then
        docker logs "$name" >&2
        echo 'systemd did not become ready within 60 seconds.' >&2
        exit 1
    fi
    sleep 1
done
# Copy a snapshot before execution to avoid mixing versions during a long test.
# Copy only the public template; generate test secrets inside the container.
docker cp "$root/tests/docker/." "$name:/opt/ossf-tests"
docker exec "$name" mkdir -p /opt/ossf-scripts/config
for directory in "$root"/install-* "$root/scripts"; do
    docker cp "$directory" "$name:/opt/ossf-scripts/"
done
docker cp "$root/config/ossf.env.example" "$name:/opt/ossf-scripts/config/"
docker exec "$name" bash /opt/ossf-tests/create-test-config.sh /opt/ossf-scripts
if [[ $target == failures ]]; then
    docker exec "$name" bash /opt/ossf-tests/check-failures.sh /opt/ossf-scripts
    completed=1
    exit 0
fi
# credential identifies the persistent file whose checksum must remain unchanged on reruns.
case $target in
    nexus) installer=install-nexus/nexus-ubuntu-server.sh; credential=/etc/ossf/nexus-config.sha256 ;;
    gitlab) installer=install-gitlab-ce/gitlab-ubuntu-server.sh; credential=/etc/gitlab/gitlab-secrets.json ;;
    defectdojo)
        installer=install-defectdojo/defectdojo-ubuntu-server.sh
        credential=/opt/defectdojo/.ossf.env
        docker exec "$name" bash /opt/ossf-tests/setup-docker.sh > "$log_dir/docker-setup.log" 2>&1
        ;;
    sonarqube)
        installer=install-sonarqube/sonarqube-ubuntu-server.sh
        credential=/etc/ossf/sonarqube-db-password
        if [[ -n ${SONARQUBE_ARCHIVE:-} ]]; then
            docker cp "$SONARQUBE_ARCHIVE" "$name:/var/tmp/sonarqube.zip"
        fi
        ;;
esac
# Scripts, shared reader and a fresh test configuration were snapshotted above.
# SONARQUBE_ARCHIVE is a test harness input here: copy the local ZIP if provided.
# The second installation without --archive must succeed using the existing installation.
args=()
[[ $target != gitlab ]] || args=(-d gitlab.ossf.test)
if [[ $target == sonarqube && -n ${SONARQUBE_ARCHIVE:-} ]]; then args=(--archive /var/tmp/sonarqube.zip); fi
echo "Installing $target in $name ..."
# Conditional expansion of the empty array preserves Bash 3.2 compatibility (macOS).
# 2400 bounds the entire installation, independently of the readiness WAIT_TIMEOUT.
docker exec "$name" bash -c 'timeout 2400 bash "$@" > /var/log/ossf-install.log 2>&1' bash "/opt/ossf-scripts/$installer" ${args[@]+"${args[@]}"}
docker exec "$name" bash /opt/ossf-tests/verify.sh "$target"
if [[ $target == gitlab ]]; then
    docker cp "$root/samples-gitlab-ci" "$name:/opt/ossf-ci"
    docker exec "$name" timeout 300 gitlab-rails runner /opt/ossf-tests/check-gitlab-ci.rb /opt/ossf-ci
fi
# Check that secrets and configuration stay unchanged, then repeat runtime verification.
docker exec "$name" bash -c 'sha256sum "$1" /opt/ossf-scripts/config/ossf.env > /var/tmp/credentials.sha256' bash "$credential"
[[ $target != sonarqube ]] || args=()
echo "Checking a second installation of $target ..."
docker exec "$name" bash -c 'timeout 2400 bash "$@" > /var/log/ossf-rerun.log 2>&1' bash "/opt/ossf-scripts/$installer" ${args[@]+"${args[@]}"}
docker exec "$name" sha256sum --check /var/tmp/credentials.sha256
docker exec "$name" python3 /opt/ossf-tests/check-secret-output.py \
    /opt/ossf-scripts/config/ossf.env /var/log/ossf-install.log /var/log/ossf-rerun.log
docker exec "$name" bash /opt/ossf-tests/verify.sh "$target"
completed=1
