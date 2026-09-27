#!/bin/bash
# VM 1: native GitLab CE and Runner; settings GITLAB_*, RUNNER_VERSION, WAIT_TIMEOUT.
# This script installs the Runner; registering it with GitLab remains a separate step.
# Install GitLab CE and GitLab Runner on Ubuntu 26.04.
set -Eeuo pipefail
umask 022
export DEBIAN_FRONTEND=noninteractive

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }
# Preserve the failure status without exposing the command arguments or environment.
on_error() {
    local code=$1 line=$2
    printf 'ERROR: installation stopped at line %s (exit %s).\n' "$line" "$code" >&2
    exit "$code"
}
trap 'on_error "$?" "$LINENO"' ERR
project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/config.sh
. "$project_root/scripts/config.sh"

# Check the target VM before installation; help and CLI parsing remain available.
preflight() {
    [[ $EUID -eq 0 ]] || die "Run this script as root (sudo bash $0)."
    [[ -r /etc/os-release ]] || die "Ubuntu 26.04 is required."
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ $ID == ubuntu && $VERSION_ID == 26.04 ]] || die "This installer targets Ubuntu 26.04."
    [[ -d /run/systemd/system ]] || die "A running systemd is required; a plain Docker container is insufficient."
}

# Wait for application readiness within a deadline, not merely an open port.
wait_http() {
    local url=$1 deadline=$((SECONDS + ${WAIT_TIMEOUT:-900}))
    until curl --fail --silent --max-time 10 "$url" >/dev/null; do
        (( SECONDS < deadline )) || die "Timed out waiting for $url; inspect the service logs."
        sleep 5
    done
}

usage() {
    echo "Usage: sudo bash $0 [-d gitlab.example.com] (default: GITLAB_DOMAIN in config/ossf.env)"
    echo "Configuration: GITLAB_VERSION (19.4.1-ce.0), RUNNER_VERSION (19.4.1-1), WAIT_TIMEOUT."
}
# An explicit -d value overrides GITLAB_DOMAIN after the file is loaded.
domain=
while (( $# )); do
    case $1 in
        -h|--help) usage; exit 0 ;;
        -d|--domain-var)
            [[ $# -ge 2 && -n $2 ]] || die "Missing domain after $1."
            domain=$2; shift 2 ;;
        *) die "Unknown argument: $1" ;;
    esac
done
preflight
ossf_load_config "$project_root"
domain=${domain:-$GITLAB_DOMAIN}
[[ -n $domain ]] || die "Specify GITLAB_DOMAIN in the configuration or a domain with -d."
# Domain only: reject URLs, whitespace, shell/Ruby metacharacters and option injection.
[[ ${#domain} -le 253 && $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ && $domain != *..* ]] || die "Invalid domain: use a hostname without scheme, path or port."
IFS=. read -r -a labels <<< "$domain"
for label in "${labels[@]}"; do
    [[ ${#label} -le 63 && $label != -* && $label != *- ]] || die "Invalid domain label."
done
[[ $GITLAB_ADMIN_USER == root ]] || die "GitLab's initial administrator must be root."
[[ $GITLAB_ROOT_EMAIL =~ ^[^[:space:]@]+@[^[:space:]@]+$ ]] || die "Invalid GITLAB_ROOT_EMAIL."
ossf_require_secret GITLAB_ROOT_PASSWORD
ossf_check_state gitlab GITLAB_ROOT_EMAIL GITLAB_ROOT_PASSWORD
case $(dpkg --print-architecture) in amd64|arm64) ;; *) die "GitLab requires amd64 or arm64." ;; esac
install -d -m 700 /etc/ossf
# The marker permits an identical rerun, not adoption of an unknown configuration.
marker=/etc/ossf/gitlab-domain
if [[ -f $marker ]]; then
    [[ $(cat "$marker") == "$domain" ]] || die "This installation uses a different domain; change gitlab.rb manually."
elif [[ -s /etc/gitlab/gitlab.rb ]]; then
    die "Existing unmanaged GitLab configuration found. Use the upstream upgrade procedure."
fi
printf '%s\n' "$domain" > "$marker"
chmod 600 "$marker"
apt-get update
apt-get install -y --no-install-recommends curl ca-certificates openssh-server tzdata perl gnupg
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
# Download official repository setup scripts before executing them so errors propagate.
for repository in gitlab/gitlab-ce runner/gitlab-runner; do
    repo_file=/etc/apt/sources.list.d/${repository//\//_}.list
    if [[ ! -s $repo_file ]]; then
        curl --fail --location --retry 3 \
            "https://packages.gitlab.com/install/repositories/$repository/script.deb.sh" \
            -o "$work_dir/repository.sh"
        bash "$work_dir/repository.sh"
    fi
done
apt-get update

# Preserve the installed version; switching versions requires an explicit migration.
# ROOT_EMAIL/ROOT_PASSWORD initialize the root WEB account on the first installation.
install_package() {
    local name=$1 requested=$2 installed='' package=$1
    if dpkg-query -W -f='${Status}' "$name" 2>/dev/null | grep -qx 'install ok installed'; then
        installed=$(dpkg-query -W -f='${Version}' "$name")
        [[ -z $requested || $requested == "$installed" ]] || die "$name $installed is installed; upgrades require the upstream procedure."
        package=$name=$installed
    elif [[ -n $requested ]]; then
        package=$name=$requested
    fi
    GITLAB_ROOT_EMAIL=$GITLAB_ROOT_EMAIL GITLAB_ROOT_PASSWORD=$GITLAB_ROOT_PASSWORD \
        EXTERNAL_URL="http://$domain" apt-get install -y "$package"
}
install_package gitlab-ce "${GITLAB_VERSION:-19.4.1-ce.0}"
install_package gitlab-runner "${RUNNER_VERSION:-19.4.1-1}"
gitlab-ctl reconfigure
systemctl enable --now gitlab-runsvdir gitlab-runner
wait_http 'http://127.0.0.1/-/readiness?all=1'
# Verify the configured password in Rails without including it in process arguments.
# Save the digest only after GitLab is ready and authentication succeeds.
OSSF_GITLAB_PASSWORD=$GITLAB_ROOT_PASSWORD gitlab-rails runner \
    'u = User.find_by_username("root"); abort "Configured GitLab password does not match the installed account" unless u && u.valid_password?(ENV.fetch("OSSF_GITLAB_PASSWORD"))'
ossf_save_state
log "GitLab is ready at http://$domain. Configure DNS to point to this server."
log "Administrator credentials: $OSSF_CONFIG (GITLAB_ADMIN_USER / GITLAB_ROOT_PASSWORD)."
log "Runner is installed. Register it using your GitLab instance's runner authentication token."
