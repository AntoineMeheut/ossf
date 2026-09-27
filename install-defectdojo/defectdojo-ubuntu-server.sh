#!/bin/bash
# VM 1: DefectDojo Docker stack; settings DEFECTDOJO_VERSION, INSTALL_DIR, DD_*, WAIT_TIMEOUT.
# Install Docker/Compose first. PostgreSQL and Valkey remain inside this stack.
# Install a pinned DefectDojo release using its upstream Compose configuration.
set -Eeuo pipefail
umask 022
export DEBIAN_FRONTEND=noninteractive

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }
# Preserve the status without printing the command, which may contain secrets.
on_error() {
    local code=$1 line=$2
    printf 'ERROR: installation stopped at line %s (exit %s).\n' "$line" "$code" >&2
    exit "$code"
}
trap 'on_error "$?" "$LINENO"' ERR
project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/config.sh
. "$project_root/scripts/config.sh"

# Check the target VM before running APT or creating the stack.
preflight() {
    [[ $EUID -eq 0 ]] || die "Run this script as root (sudo bash $0)."
    [[ -r /etc/os-release ]] || die "Ubuntu 26.04 is required."
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ $ID == ubuntu && $VERSION_ID == 26.04 ]] || die "This installer targets Ubuntu 26.04."
    [[ -d /run/systemd/system ]] || die "A running systemd is required; a plain Docker container is insufficient."
}

# Final HTTP check after the initialization container succeeds.
wait_http() {
    local url=$1 deadline=$((SECONDS + ${WAIT_TIMEOUT:-900}))
    until curl --fail --silent --max-time 10 "$url" >/dev/null; do
        (( SECONDS < deadline )) || die "Timed out waiting for $url; inspect the service logs."
        sleep 5
    done
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    echo "Usage: sudo bash $0 (configuration: OSSF_CONFIG or config/ossf.env)"
    echo "Configuration: DEFECTDOJO_VERSION (3.3.200), INSTALL_DIR (/opt/defectdojo),"
    echo "             DD_PORT (8088), DD_TLS_PORT (8443), WAIT_TIMEOUT (seconds)."
    echo "Requires a working Docker Engine and Docker Compose plugin."
    exit 0
fi
[[ $# -eq 0 ]] || die "Unexpected argument: $1"
preflight
ossf_load_config "$project_root"
for secret in DD_ADMIN_PASSWORD DD_DATABASE_PASSWORD DD_SECRET_KEY; do ossf_require_secret "$secret"; done
[[ $DD_CREDENTIAL_AES_256_KEY =~ ^[[:xdigit:]]{32}$ ]] || die "DD_CREDENTIAL_AES_256_KEY must contain 32 hexadecimal characters."
[[ $DD_ADMIN_USER =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]] || die "Invalid DD_ADMIN_USER."
[[ $DD_ADMIN_MAIL =~ ^[^[:space:]@]+@[^[:space:]@]+$ ]] || die "Invalid DD_ADMIN_MAIL."
[[ $DD_DATABASE_USER == defectdojo && $DD_DATABASE_NAME == defectdojo ]] || die "Upstream Compose requires database user/name defectdojo."
# Preserve secrets, keys, ports and path: a rerun must not change the existing stack.
ossf_check_state defectdojo DD_ADMIN_USER DD_ADMIN_MAIL DD_ADMIN_PASSWORD DD_DATABASE_PASSWORD DD_SECRET_KEY DD_CREDENTIAL_AES_256_KEY DD_PORT DD_TLS_PORT INSTALL_DIR
command -v docker >/dev/null || die "Install Docker Engine and the Docker Compose plugin first."
docker info >/dev/null 2>&1 || die "Cannot connect to Docker Engine."
docker compose version >/dev/null 2>&1 || die "Docker Compose plugin is required."
version=$DEFECTDOJO_VERSION
# Populated by the literal configuration reader.
# shellcheck disable=SC2153
install_dir=$INSTALL_DIR
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "DEFECTDOJO_VERSION must be a release number."
[[ $install_dir =~ ^/[a-zA-Z0-9/_.-]+$ && $install_dir != / ]] || die "INSTALL_DIR must be an absolute path without spaces."
for port in "$DD_PORT" "$DD_TLS_PORT"; do
    [[ $port =~ ^[1-9][0-9]{0,4}$ ]] || die "Invalid TCP port."
    (( port <= 65535 )) || die "Invalid TCP port."
done
[[ $DD_PORT != "$DD_TLS_PORT" ]] || die "HTTP and TLS ports must differ."
# Require the marker for this version; upgrades must follow the vendor's procedure.
if [[ -e $install_dir ]]; then
    [[ -f $install_dir/.ossf-version ]] || die "$install_dir is not managed by this installer."
    [[ $(cat "$install_dir/.ossf-version") == "$version" ]] || die "Use the upstream upgrade procedure to change DefectDojo versions."
fi
apt-get update
apt-get install -y --no-install-recommends git curl ca-certificates openssl
if [[ ! -d $install_dir ]]; then
    git clone --depth 1 --branch "$version" https://github.com/DefectDojo/django-DefectDojo.git "$install_dir"
    printf '%s\n' "$version" > "$install_dir/.ossf-version"
fi
# Check that the checkout still matches the requested tag, including on reruns.
cd "$install_dir"
[[ $(git rev-parse HEAD) == "$(git rev-parse "refs/tags/$version^{commit}")" ]] || die "The checkout does not match the requested release."
if [[ ! -f .ossf.env ]] && docker volume inspect ossf-defectdojo_defectdojo_postgres >/dev/null 2>&1; then
    die "Existing database volume found without .ossf.env; restore the original configuration."
fi
# This derived runtime file is checked against the central configuration on reruns.
# Compose receives literal values from the environment, avoiding .env interpolation.
# .ossf.env detects configuration drift; do not edit it or supply it as a dotenv file.
# Preserve this copy and the central keys alongside persistent volume backups.
ossf_defectdojo_environment
env_candidate=$(mktemp)
chmod 600 "$env_candidate"
for key in DJANGO_VERSION NGINX_VERSION DD_PORT DD_TLS_PORT DD_DATABASE_PASSWORD DD_DATABASE_URL DD_SECRET_KEY DD_CREDENTIAL_AES_256_KEY DD_ADMIN_USER DD_ADMIN_MAIL DD_ADMIN_PASSWORD; do
    printf '%s=%s\n' "$key" "${!key}" >> "$env_candidate"
done
if [[ -f .ossf.env ]] && ! cmp -s .ossf.env "$env_candidate"; then
    rm -f "$env_candidate"
    die "Existing DefectDojo credentials/settings differ; import the original .ossf.env values into the central configuration."
fi
install -m 600 "$env_candidate" .ossf.env
rm -f "$env_candidate"
# Extend upstream Compose: restart persistent services, never the initializer.
# The quoted 'EOF' preserves ${...} for Compose, which requires the exported secrets.
cat > docker-compose.ossf.yml <<'EOF'
services:
  nginx:
    restart: unless-stopped
  uwsgi:
    restart: unless-stopped
  celerybeat:
    restart: unless-stopped
  celeryworker:
    restart: unless-stopped
  postgres:
    restart: unless-stopped
  valkey:
    restart: unless-stopped
  initializer:
    environment:
      DD_ADMIN_MAIL: "${DD_ADMIN_MAIL:?}"
      DD_ADMIN_PASSWORD: "${DD_ADMIN_PASSWORD:?}"
EOF
# The project name determines volume names; use the same name in the maintenance wrapper.
# /dev/null prevents a dotenv reader from interpreting special characters.
compose() {
    docker compose --project-name ossf-defectdojo --env-file /dev/null \
        -f docker-compose.yml -f docker-compose.ossf.yml "$@"
}
compose config --quiet
compose pull
# Complete migrations and administrator creation before starting the full application.
compose up -d --no-build initializer
initializer=$(compose ps -a -q initializer)
[[ -n $initializer ]] || die "The initializer container was not created."
deadline=$((SECONDS + ${WAIT_TIMEOUT:-900}))
while :; do
    state=$(docker inspect --format '{{.State.Status}}' "$initializer")
    if [[ $state == exited ]]; then
        code=$(docker inspect --format '{{.State.ExitCode}}' "$initializer")
        [[ $code == 0 ]] || die "DefectDojo initialization failed ($code); inspect Compose initializer logs."
        break
    fi
    [[ $state != dead ]] || die "The initializer container is dead."
    (( SECONDS < deadline )) || die "DefectDojo initialization timed out; inspect Compose logs."
    sleep 5
done
compose up -d --no-build
wait_http "http://127.0.0.1:$DD_PORT/login"
ossf_save_state
log "DefectDojo is ready on port $DD_PORT. User: $DD_ADMIN_USER."
log "Credentials are read from $OSSF_CONFIG; .ossf.env is a generated runtime copy."
