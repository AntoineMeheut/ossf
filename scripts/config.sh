#!/bin/bash
# Library shared by the installers on VMs 1/2/3 and the DefectDojo wrapper.
# Source this library from the repository; config/ossf.env is read as data, never executed.
# Shared configuration reader. Values are data: never source/eval the private file.
# Errors identify the key or line, never a secret value.
ossf_config_error() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Argument: repository root. Load defaults first, then the private copy.
# OSSF_CONFIG selects a different file; individual shell variables are
# overwritten by the configuration. CLI options are applied afterwards.
ossf_load_config() {
    local root=$1 file line key value allowed='' seen='' mode number=0
    file=${OSSF_CONFIG:-$root/config/ossf.env}
    [[ -f $file && -r $file ]] || ossf_config_error "Configuration missing or unreadable: $file. Run bash scripts/init-config.sh."
    # GNU stat on Ubuntu, BSD stat on macOS; reject group/other access.
    mode=$(stat -c %a "$file" 2>/dev/null) || mode=$(stat -f %Lp "$file")
    (( (8#$mode & 077) == 0 )) || ossf_config_error "Configuration must be private: chmod 600 $file"
    # Only names declared by the repository's template are accepted.
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line =~ ^[A-Z][A-Z0-9_]*= ]] || continue
        key=${line%%=*}
        allowed="$allowed $key "
        printf -v "$key" '%s' "${line#*=}"
    done < "$root/config/ossf.env.example"
    # read -r and printf -v preserve $, backslashes and spaces without Bash evaluation.
    # Declare new variables in ossf.env.example before using them here.
    while IFS= read -r line || [[ -n $line ]]; do
        number=$((number + 1))
        [[ -z $line || $line == \#* ]] && continue
        [[ $line =~ ^[A-Z][A-Z0-9_]*= && $line != *$'\r'* ]] || ossf_config_error "Invalid configuration syntax at line $number (use literal KEY=value)."
        key=${line%%=*}
        value=${line#*=}
        [[ $allowed == *" $key "* ]] || ossf_config_error "Unknown configuration key at line $number."
        [[ $seen != *" $key "* ]] || ossf_config_error "Duplicate configuration key: $key"
        seen="$seen $key "
        printf -v "$key" '%s' "$value"
    done < "$file"
    # Make the path independent of subsequent directory changes in the installers.
    OSSF_CONFIG=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")
    [[ $WAIT_TIMEOUT =~ ^[1-9][0-9]*$ ]] || ossf_config_error "WAIT_TIMEOUT must be a positive number of seconds."
}

# Argument: variable name, not its contents. Apply the shared minimum ASCII checks;
# applications may enforce additional password-strength requirements.
ossf_require_secret() {
    local key=$1 value
    local LC_ALL=C
    value=${!key}
    [[ ${#value} -ge 16 && $value != *[![:print:]]* ]] || ossf_config_error "$key must contain at least 16 printable characters in the configuration."
}

# Arguments: service followed by an ordered list of keys to preserve after installation.
# The digest detects changes on reruns; it is not a backup of the secret.
# NUL separators prevent ambiguity between keys/values containing spaces.
ossf_check_state() {
    local service=$1 key
    shift
    OSSF_STATE_FILE=/etc/ossf/$service-config.sha256
    OSSF_STATE_DIGEST=$({ for key in "$@"; do printf '%s\0%s\0' "$key" "${!key}"; done; } | sha256sum)
    OSSF_STATE_DIGEST=${OSSF_STATE_DIGEST%% *}
    if [[ -f $OSSF_STATE_FILE ]]; then
        [[ $(cat "$OSSF_STATE_FILE") == "$OSSF_STATE_DIGEST" ]] || ossf_config_error "Saved $service credentials/settings differ from the configuration. Restore its original values; password rotation is a separate operation."
    fi
}

# Call only after success: persist the digest prepared by check_state.
ossf_save_state() {
    install -d -m 700 /etc/ossf
    (umask 077; printf '%s\n' "$OSSF_STATE_DIGEST" > "$OSSF_STATE_FILE")
}

# Authentication stays out of curl's process arguments and output.
# Arguments: username, password, then curl options. Pass the header through stdin.
# Do not enable shell tracing or HTTP logging that includes Authorization.
ossf_curl() {
    local user=$1 password=$2 encoded
    shift 2
    encoded=$(printf '%s:%s' "$user" "$password" | base64 | tr -d '\n')
    printf 'header = "Authorization: Basic %s"\n' "$encoded" | \
        curl --silent --show-error --max-time 30 --config - "$@"
}

# Encode a URL COMPONENT byte by byte, such as the DefectDojo PostgreSQL
# password; do not apply this function to the entire URL.
ossf_urlencode() {
    local value=$1 char code index
    local LC_ALL=C
    for ((index=0; index<${#value}; index++)); do
        char=${value:index:1}
        case $char in
            [a-zA-Z0-9.~_-]) printf '%s' "$char" ;;
            *) printf -v code '%02X' "'$char"; printf '%%%s' "$code" ;;
        esac
    done
}

# Escape the JDBC password for sonar.properties (VM 2), not for Bash.
ossf_java_property() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value// /\\ }
    printf '%s' "$value"
}

# VM 1: export only the DefectDojo stack settings to Compose.
# postgres is a service name on its Docker network, not the SonarQube VM.
# Keep the Django and Nginx images aligned on the same release tag.
ossf_defectdojo_environment() {
    export DJANGO_VERSION=$DEFECTDOJO_VERSION NGINX_VERSION=$DEFECTDOJO_VERSION
    export DD_PORT DD_TLS_PORT DD_DATABASE_PASSWORD DD_SECRET_KEY DD_CREDENTIAL_AES_256_KEY
    export DD_ADMIN_USER DD_ADMIN_MAIL DD_ADMIN_PASSWORD
    DD_DATABASE_URL="postgresql://$DD_DATABASE_USER:$(ossf_urlencode "$DD_DATABASE_PASSWORD")@postgres:5432/$DD_DATABASE_NAME"
    export DD_DATABASE_URL
}
