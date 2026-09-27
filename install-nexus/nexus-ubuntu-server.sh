#!/bin/bash
# VM 3: native Nexus; settings NEXUS_* and WAIT_TIMEOUT in config/ossf.env.
# Use the Java runtime supplied by Sonatype, independently of the SonarQube VM's JDK.
# Install Nexus Repository 3.96 on Ubuntu 26.04 (amd64 or arm64).
set -Eeuo pipefail
umask 022
export DEBIAN_FRONTEND=noninteractive

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }
# Propagate the status without printing the command or any secrets it contains.
on_error() {
    local code=$1 line=$2
    printf 'ERROR: installation stopped at line %s (exit %s).\n' "$line" "$code" >&2
    exit "$code"
}
trap 'on_error "$?" "$LINENO"' ERR
project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/config.sh
. "$project_root/scripts/config.sh"

# Require the target Ubuntu VM with systemd before making system changes.
preflight() {
    [[ $EUID -eq 0 ]] || die "Run this script as root (sudo bash $0)."
    [[ -r /etc/os-release ]] || die "Ubuntu 26.04 is required."
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ $ID == ubuntu && $VERSION_ID == 26.04 ]] || die "This installer targets Ubuntu 26.04."
    [[ -d /run/systemd/system ]] || die "A running systemd is required; a plain Docker container is insufficient."
}

# Check local API readiness; administrator authentication is verified afterwards.
wait_http() {
    local url=$1 deadline=$((SECONDS + ${WAIT_TIMEOUT:-900}))
    until curl --fail --silent --max-time 10 "$url" >/dev/null; do
        (( SECONDS < deadline )) || die "Timed out waiting for $url; inspect the service logs."
        sleep 5
    done
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    echo "Usage: sudo bash $0 (configuration: OSSF_CONFIG or config/ossf.env)"
    echo "Configuration: NEXUS_VERSION (default 3.96.3-01), WAIT_TIMEOUT (seconds)."
    exit 0
fi
[[ $# -eq 0 ]] || die "Unexpected argument: $1"
preflight
ossf_load_config "$project_root"
[[ $NEXUS_ADMIN_USER == admin ]] || die "Nexus's initial administrator must be admin."
ossf_require_secret NEXUS_ADMIN_PASSWORD
ossf_check_state nexus NEXUS_ADMIN_USER NEXUS_ADMIN_PASSWORD
version=${NEXUS_VERSION:-3.96.3-01}
[[ $version =~ ^3\.[0-9]+\.[0-9]+-[0-9]+$ ]] || die "Invalid NEXUS_VERSION."
# Sonatype archive architecture names differ from Debian package architecture names.
case $(dpkg --print-architecture) in
    amd64) arch=x86_64 ;;
    arm64) arch=aarch_64 ;;
    *) die "Nexus requires amd64 or arm64." ;;
esac
# Versioned binaries live in /opt/nexus-...; persistent data lives in /opt/sonatype-work.
# Do not use this script to adopt or migrate an existing Nexus database.
install_dir=/opt/nexus-$version
if [[ -e $install_dir && ! -f $install_dir/.ossf-managed ]]; then
    die "$install_dir already exists and is not managed by this installer."
fi
if [[ -f $install_dir/.ossf-managed ]]; then
    [[ $(cat "$install_dir/.ossf-managed") == "$version" ]] || die "Use the upstream upgrade procedure to change Nexus versions."
fi
if [[ -e /opt/sonatype-work && ! -f $install_dir/.ossf-managed ]]; then
    die "Existing Nexus data found. Use the upstream upgrade procedure instead."
fi
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl tar gzip
# Unix service account without an interactive shell, distinct from the admin WEB account.
getent group nexus >/dev/null || groupadd --system nexus
id nexus >/dev/null 2>&1 || useradd --system --gid nexus --home-dir /opt/sonatype-work --shell /usr/sbin/nologin nexus

if [[ ! -f $install_dir/.ossf-managed ]]; then
    work_dir=$(mktemp -d)
    trap 'rm -rf -- "$work_dir"' EXIT
    archive=nexus-$version-linux-$arch.tar.gz
    url=https://download.sonatype.com/nexus/3/$archive
    log "Downloading Nexus $version ($arch), with its bundled Java runtime."
    curl --fail --location --retry 3 "$url" -o "$work_dir/$archive"
    # Verify the archive against the checksum published by the same official HTTPS source.
    curl --fail --silent --show-error --location --retry 3 "$url.sha256" -o "$work_dir/checksum"
    checksum=$(awk '{print $1}' "$work_dir/checksum")
    [[ $checksum =~ ^[[:xdigit:]]{64}$ ]] || die "Invalid Nexus SHA-256 checksum."
    (cd "$work_dir"; printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check -)
    tar -xzf "$work_dir/$archive" -C "$work_dir"
    # /tmp may be mounted noexec; check executability after moving to /opt.
    [[ -f $work_dir/nexus-$version/bin/nexus ]] || die "Unexpected archive layout."
    printf '%s\n' "$version" > "$work_dir/nexus-$version/.ossf-managed"
    mv "$work_dir/nexus-$version" "$install_dir"
    # Create the data directory separately: never overwrite an existing database.
    install -d -o nexus -g nexus /opt/sonatype-work/nexus3
fi
[[ -x $install_dir/bin/nexus ]] || die "The Nexus launcher is not executable under /opt."
chown -R nexus:nexus "$install_dir" /opt/sonatype-work
printf 'run_as_user="nexus"\n' > "$install_dir/bin/nexus.rc"
# nexus run stays in the foreground so systemd can supervise its process directly.
cat > /etc/systemd/system/nexus.service <<EOF
[Unit]
Description=Nexus Repository
After=network.target

[Service]
Type=simple
User=nexus
Group=nexus
WorkingDirectory=$install_dir
ExecStart=$install_dir/bin/nexus run
LimitNOFILE=65536
TimeoutStopSec=120
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable nexus
systemctl restart nexus
wait_http http://127.0.0.1:8081/service/rest/v1/status
# If the configured secret works, reruns leave the account unchanged.
# Otherwise, only the initial password generated by Nexus permits initial setup.
if ! ossf_curl "$NEXUS_ADMIN_USER" "$NEXUS_ADMIN_PASSWORD" --fail --output /dev/null \
    http://127.0.0.1:8081/service/rest/v1/security/users 2>/dev/null; then
    initial_password_file=/opt/sonatype-work/nexus3/admin.password
    [[ -s $initial_password_file ]] || die "Cannot authenticate Nexus; import the current admin password into the configuration."
    initial_password=$(cat "$initial_password_file")
    # Send the new password from a private file, not through curl arguments.
    secret_body=$(mktemp)
    chmod 600 "$secret_body"
    printf '%s' "$NEXUS_ADMIN_PASSWORD" > "$secret_body"
    if ! ossf_curl admin "$initial_password" --fail --request PUT \
        --header 'Content-Type: text/plain' --data-binary "@$secret_body" \
        http://127.0.0.1:8081/service/rest/v1/security/users/admin/change-password >/dev/null; then
        rm -f "$secret_body"
        die "Cannot configure Nexus admin; import the current password for an existing instance."
    fi
    rm -f "$secret_body"
fi
ossf_curl "$NEXUS_ADMIN_USER" "$NEXUS_ADMIN_PASSWORD" --fail --output /dev/null \
    http://127.0.0.1:8081/service/rest/v1/security/users
ossf_save_state
log "Nexus is ready on port 8081. Administrator credentials: $OSSF_CONFIG."
