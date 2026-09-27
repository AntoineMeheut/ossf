#!/bin/bash
# VM 2: native SonarQube and local PostgreSQL; settings SONARQUBE_* and WAIT_TIMEOUT.
# The database listens on localhost:5432 on this VM, independently of DefectDojo (VM 1).
# Install SonarQube Community Build with Ubuntu's PostgreSQL 18 and JDK 25.
set -Eeuo pipefail
umask 022
export DEBIAN_FRONTEND=noninteractive

log() { printf '[%s] %s\n' "$(date -Is)" "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }
# Print only the line and status to avoid logging secrets from commands.
on_error() {
    local code=$1 line=$2
    printf 'ERROR: installation stopped at line %s (exit %s).\n' "$line" "$code" >&2
    exit "$code"
}
trap 'on_error "$?" "$LINENO"' ERR
project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/config.sh
. "$project_root/scripts/config.sh"

# Check Ubuntu, root and systemd before modifying packages or system files.
preflight() {
    [[ $EUID -eq 0 ]] || die "Run this script as root (sudo bash $0)."
    [[ -r /etc/os-release ]] || die "Ubuntu 26.04 is required."
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ $ID == ubuntu && $VERSION_ID == 26.04 ]] || die "This installer targets Ubuntu 26.04."
    [[ -d /run/systemd/system ]] || die "A running systemd is required; a plain Docker container is insufficient."
}

# --archive overrides SONARQUBE_ARCHIVE; an empty value allows downloading.
archive=
while (( $# )); do
    case $1 in
        -h|--help)
            echo "Usage: sudo bash $0 [--archive /path/to/sonarqube-26.9.0.129388.zip]"
            echo "Configuration: SONARQUBE_ARCHIVE, SONARQUBE_SHA256 (optional), WAIT_TIMEOUT."
            echo "Requires amd64 or arm64. Downloads the official ZIP unless --archive is supplied."
            exit 0 ;;
        --archive)
            [[ $# -ge 2 && -n $2 ]] || die "Missing ZIP path after --archive."
            archive=$2; shift 2 ;;
        *) die "Unexpected argument: $1" ;;
    esac
done
preflight
ossf_load_config "$project_root"
archive=${archive:-$SONARQUBE_ARCHIVE}
[[ $SONARQUBE_ADMIN_USER == admin ]] || die "SonarQube's initial administrator must be admin."
ossf_require_secret SONARQUBE_ADMIN_PASSWORD
ossf_require_secret SONARQUBE_DB_PASSWORD
for identifier in "$SONARQUBE_DB_USER" "$SONARQUBE_DB_NAME"; do
    [[ $identifier =~ ^[a-z_][a-z0-9_]*$ && ${#identifier} -le 63 ]] || die "Invalid SonarQube database user/name."
done
# Reject changes to accounts/secrets before modifying PostgreSQL.
ossf_check_state sonarqube SONARQUBE_DB_USER SONARQUBE_DB_NAME SONARQUBE_DB_PASSWORD SONARQUBE_ADMIN_PASSWORD
password_file=/etc/ossf/sonarqube-db-password
if [[ -s $password_file ]]; then
    [[ $(cat "$password_file") == "$SONARQUBE_DB_PASSWORD" ]] || die "Existing SonarQube database credentials differ; import the original password into the configuration."
fi
arch=$(dpkg --print-architecture)
case $arch in amd64|arm64) ;; *) die "SonarQube requires amd64 or arm64." ;; esac
# Maintain the version, template SHA-256, JDK/PostgreSQL, help and runtime tests together.
# The marker distinguishes a rerun of this version from a data migration.
version=26.9.0.129388
if [[ -e /opt/sonarqube && ! -f /opt/sonarqube/.ossf-managed ]]; then
    die "/opt/sonarqube already exists and is not managed by this installer."
fi
if [[ -f /opt/sonarqube/.ossf-managed ]]; then
    [[ $(cat /opt/sonarqube/.ossf-managed) == "$version" ]] || die "Use the upstream upgrade procedure to change SonarQube versions."
fi
checksum=${SONARQUBE_SHA256:-b7306f5ecfa6806753bc0eb0dc4ea11fe0ddd2c5a346592718814d6ec35b88cb}
[[ $checksum =~ ^[[:xdigit:]]{64}$ ]] || die "Invalid SONARQUBE_SHA256."
# Validate a local ZIP before APT; downloaded ZIPs are checked before extraction.
if [[ -n $archive ]]; then
    [[ -f $archive && -r $archive ]] || die "Provide a readable SonarQube $version ZIP with --archive."
    archive=$(readlink -f -- "$archive")
    printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check -
fi
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl unzip openssl procps \
    openjdk-25-jdk-headless postgresql-18
if [[ ! -f /opt/sonarqube/.ossf-managed ]]; then
    work_dir=$(mktemp -d)
    trap 'rm -rf -- "$work_dir"' EXIT
    if [[ -z $archive ]]; then
        archive=$work_dir/sonarqube.zip
        curl --fail --location --retry 3 \
            "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$version.zip" -o "$archive"
        printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check -
    fi
    unzip -q "$archive" -d "$work_dir"
    [[ -f $work_dir/sonarqube-$version/lib/sonar-application-$version.jar && -f $work_dir/sonarqube-$version/conf/sonar.properties ]] || die "Expected a SonarQube $version distribution ZIP."
    printf '%s\n' "$version" > "$work_dir/sonarqube-$version/.ossf-managed"
    mv "$work_dir/sonarqube-$version" /opt/sonarqube
fi
# Non-interactive Unix service account, distinct from the WEB administrator and SQL role.
getent group sonar >/dev/null || groupadd --system sonar
id sonar >/dev/null 2>&1 || useradd --system --gid sonar --home-dir /opt/sonarqube --shell /usr/sbin/nologin sonar

# sysctl accepts kernel parameters, not shell commands such as ulimit.
# Preserve higher host limits, including after the next boot.
# Elasticsearch prerequisites: never lower limits that are already higher.
: > /etc/sysctl.d/99-sonarqube.conf
for setting in vm.max_map_count=524288 fs.file-max=131072; do
    key=${setting%=*}
    minimum=${setting#*=}
    current=$(sysctl -n "$key")
    if (( current < minimum )); then
        sysctl -w "$setting" || die "Set $setting on the VM/host; this container cannot change that kernel parameter."
        current=$minimum
    fi
    printf '%s=%s\n' "$key" "$current" >> /etc/sysctl.d/99-sonarqube.conf
done

systemctl enable --now postgresql
# The aggregate PostgreSQL service may be active while the cluster is stopped.
pg_ctlcluster 18 main start --skip-systemctl-redirect || pg_isready -q
install -d -m 700 /etc/ossf
password=$SONARQUBE_DB_PASSWORD
(umask 077; printf '%s\n' "$password" > "$password_file")
# ON_ERROR_STOP propagates SQL errors to the installer. No interactive passwd.
# psql quotes values (:'...') and identifiers (:"...", format %I) separately.
# Create the role/database only if missing; retain the password validated above.
(cd /tmp; runuser -u postgres -- psql --no-psqlrc --set=ON_ERROR_STOP=1 --set=db_password="$password" --set=db_user="$SONARQUBE_DB_USER" --set=db_name="$SONARQUBE_DB_NAME" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', :'db_user') WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_user')\gexec
ALTER ROLE :"db_user" PASSWORD :'db_password';
SELECT format('CREATE DATABASE %I OWNER %I ENCODING ''UTF8'' TEMPLATE template0', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name')\gexec
SQL
)

properties=/opt/sonarqube/conf/sonar.properties
# Replace by key, independently of line numbers in the upstream file.
# Write exactly one occurrence of each JDBC key, escaping for the Java properties format.
sed -i '/^[#[:space:]]*sonar\.jdbc\.username=/d; /^[#[:space:]]*sonar\.jdbc\.password=/d; /^[#[:space:]]*sonar\.jdbc\.url=/d' "$properties"
cat >> "$properties" <<EOF
sonar.jdbc.username=$SONARQUBE_DB_USER
sonar.jdbc.password=$(ossf_java_property "$password")
sonar.jdbc.url=jdbc:postgresql://localhost:5432/$SONARQUBE_DB_NAME
EOF
chown -R sonar:sonar /opt/sonarqube
chmod 640 "$properties"
# Launch the JAR with Ubuntu JDK 25 for the current architecture, without a native wrapper.
# Process/file limits belong in systemd; kernel limits belong in sysctl.
cat > /etc/systemd/system/sonar.service <<EOF
[Unit]
Description=SonarQube
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=sonar
Group=sonar
WorkingDirectory=/opt/sonarqube
Environment=JAVA_HOME=/usr/lib/jvm/java-25-openjdk-$arch
ExecStart=/usr/lib/jvm/java-25-openjdk-$arch/bin/java -Xms32m -Xmx32m -Djava.net.preferIPv4Stack=true -jar /opt/sonarqube/lib/sonar-application-$version.jar
LimitNOFILE=131072
LimitNPROC=8192
TasksMax=8192
TimeoutStartSec=180
TimeoutStopSec=120
Restart=on-failure
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable sonar
systemctl restart sonar
# A listening HTTP port does not mean that database migration has finished.
# UP confirms that migrations and Elasticsearch startup have completed.
deadline=$((SECONDS + ${WAIT_TIMEOUT:-900}))
until curl --fail --silent --max-time 10 http://127.0.0.1:9000/api/system/status | grep -Eq '"status"[[:space:]]*:[[:space:]]*"UP"'; do
    systemctl is-active --quiet sonar || die "SonarQube stopped during startup; inspect /opt/sonarqube/logs."
    (( SECONDS < deadline )) || die "SonarQube did not reach UP; inspect /opt/sonarqube/logs."
    sleep 5
done
# Verify the central WEB credentials through the API before initializing the password.
sonar_authenticated() {
    ossf_curl "$SONARQUBE_ADMIN_USER" "$SONARQUBE_ADMIN_PASSWORD" --fail \
        http://127.0.0.1:9000/api/authentication/validate | grep -Eq '"valid"[[:space:]]*:[[:space:]]*true'
}
# The only fallback is the fresh admin/admin account, never a forced password reset.
# Send the new secret from a private temporary file, then remove that file.
if ! sonar_authenticated; then
    secret_body=$(mktemp)
    chmod 600 "$secret_body"
    printf '%s' "$SONARQUBE_ADMIN_PASSWORD" > "$secret_body"
    if ! ossf_curl admin admin --fail --request POST \
        --data-urlencode login=admin --data-urlencode previousPassword=admin \
        --data-urlencode "password@$secret_body" \
        http://127.0.0.1:9000/api/users/change_password >/dev/null; then
        rm -f "$secret_body"
        die "Cannot configure SonarQube admin. For an existing instance, import its current password."
    fi
    rm -f "$secret_body"
    sonar_authenticated || die "SonarQube administrator authentication failed."
fi
ossf_save_state
log "SonarQube is UP on port 9000. Administrator credentials: $OSSF_CONFIG."
