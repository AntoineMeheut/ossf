#!/bin/bash
# VM 1: Docker for DefectDojo and Runner jobs using the Docker executor.
# Configuration: DOCKER_VERSION, COMPOSE_VERSION and WAIT_TIMEOUT in config/ossf.env.
# Install Docker Engine and Compose from the official stable APT repository.
set -Eeuo pipefail
umask 022
export DEBIAN_FRONTEND=noninteractive

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }
# Preserve the failure status without printing the command, which may contain a secret.
on_error() {
    local code=$1 line=$2
    printf 'ERROR: installation stopped at line %s (exit %s).\n' "$line" "$code" >&2
    exit "$code"
}
trap 'on_error "$?" "$LINENO"' ERR
project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/config.sh
. "$project_root/scripts/config.sh"

# Require a running Ubuntu systemd instance; an ordinary Docker container is insufficient.
preflight() {
    [[ $EUID -eq 0 ]] || die "Run this script as root (sudo bash $0)."
    [[ -r /etc/os-release ]] || die "Ubuntu 26.04 is required."
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ $ID == ubuntu && $VERSION_ID == 26.04 ]] || die "This installer targets Ubuntu 26.04."
    [[ -d /run/systemd/system ]] || die "A running systemd is required; a plain Docker container is insufficient."
}


if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    echo "Usage: sudo bash $0 (configuration: OSSF_CONFIG or config/ossf.env)"
    echo "Configuration: DOCKER_VERSION (29.8.1), COMPOSE_VERSION (5.5.1), WAIT_TIMEOUT."
    exit 0
fi
[[ $# -eq 0 ]] || die "Unexpected argument: $1"
preflight
ossf_load_config "$project_root"
version=${DOCKER_VERSION:-29.8.1}
compose_version=${COMPOSE_VERSION:-5.5.1}
for release in "$version" "$compose_version"; do
    [[ $release =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid Docker/Compose version."
done
arch=$(dpkg --print-architecture)
case $arch in amd64|arm64) ;; *) die "Docker installer requires amd64 or arm64." ;; esac
# Reject conflicting packages without removing them or migrating their data.
for package in docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc; do
    if [[ $(dpkg-query -W -f='${Status}' "$package" 2>/dev/null || true) == 'install ok installed' ]]; then
        die "Conflicting package $package is installed. Follow Docker's migration procedure first."
    fi
done
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl
# Official signed repository, restricted to the detected architecture and Ubuntu 26.04 (resolute).
install -d -m 755 /etc/apt/keyrings
curl --fail --silent --show-error --location --retry 3 https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod 644 /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: resolute
Components: stable
Architectures: $arch
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt-get update
# Resolve the full APT version (including epoch/suffix) for an x.y.z release.
# Prevent a rerun from implicitly upgrading an existing engine.
package_version() {
    local package=$1 release=$2 selected current
    selected=$(apt-cache madison "$package" | awk -v release="$release" '
        { version=$3; sub(/^[0-9]+:/, "", version); if (index(version, release "-") == 1) { print $3; exit } }')
    [[ -n $selected ]] || die "$package $release is unavailable in the stable Ubuntu 26.04 repository."
    current=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)
    [[ -z $current || $current == "$selected" ]] || die "Existing $package $current differs from $selected; use the upstream upgrade procedure."
    printf '%s' "$selected"
}
engine_package=$(package_version docker-ce "$version")
cli_package=$(package_version docker-ce-cli "$version")
compose_package=$(package_version docker-compose-plugin "$compose_version")
apt-get install -y --no-install-recommends \
    "docker-ce=$engine_package" "docker-ce-cli=$cli_package" \
    "docker-compose-plugin=$compose_package" containerd.io docker-buildx-plugin
# Check that the daemon and plugin are usable, not just that their packages are installed.
systemctl enable --now docker
deadline=$((SECONDS + ${WAIT_TIMEOUT:-900}))
until docker info >/dev/null 2>&1; do
    (( SECONDS < deadline )) || die "Docker did not start; inspect journalctl -u docker."
    sleep 2
done
[[ $(docker version --format '{{.Server.Version}}') == "$version" ]] || die "Unexpected Docker server version."
[[ $(docker compose version --short) == "$compose_version" || $(docker compose version --short) == "v$compose_version" ]] || die "Unexpected Compose version."
log "Docker $version and Compose $compose_version are ready."
