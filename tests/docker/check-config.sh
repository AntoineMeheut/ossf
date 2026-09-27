#!/bin/bash
# Test the shared configuration reader for VMs 1/2/3 with disposable secrets, never host secrets.
# SC2016 is intentional: the $ expressions below must remain literal text.
# shellcheck disable=SC2016
# Configuration behavior tests; no application installs or real credentials.
set -euo pipefail
root=${1:-/workspace}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export OSSF_CONFIG=$work/ossf.env
bash "$root/scripts/init-config.sh" "$OSSF_CONFIG" >/dev/null
# The initializer must preserve an existing configuration byte for byte.
sha256sum "$OSSF_CONFIG" > "$work/before.sha256"
bash "$root/scripts/init-config.sh" "$OSSF_CONFIG" >/dev/null
sha256sum --check --status "$work/before.sha256"
# shellcheck source=scripts/config.sh
. "$root/scripts/config.sh"
ossf_load_config "$root"
for key in GITLAB_ROOT_PASSWORD SONARQUBE_DB_PASSWORD SONARQUBE_ADMIN_PASSWORD NEXUS_ADMIN_PASSWORD DD_ADMIN_PASSWORD DD_DATABASE_PASSWORD DD_SECRET_KEY; do
    ossf_require_secret "$key"
done
[[ $GITLAB_ROOT_PASSWORD != "$NEXUS_ADMIN_PASSWORD" ]]
[[ $DD_CREDENTIAL_AES_256_KEY =~ ^[[:xdigit:]]{32}$ ]]
test "$(stat -c %a "$OSSF_CONFIG")" = 600
# Keep a valid reference copy to isolate the following invalid cases.
original=$work/original.env
cp "$OSSF_CONFIG" "$original"
expect_config_failure() {
    local message=$1
    if (ossf_load_config "$root") > "$work/output" 2>&1; then
        echo 'Expected configuration failure' >&2; exit 1
    fi
    grep -Fq "$message" "$work/output"
}
# Check permissions, allowed keys and duplicates; diagnostics must not reveal values.
chmod 644 "$OSSF_CONFIG"
expect_config_failure 'Configuration must be private'
chmod 600 "$OSSF_CONFIG"
printf 'UNKNOWN_SECRET=do-not-print-this-value\n' >> "$OSSF_CONFIG"
expect_config_failure 'Unknown configuration key'
if grep -Fq do-not-print-this-value "$work/output"; then exit 1; fi
cp "$original" "$OSSF_CONFIG"
printf 'GITLAB_DOMAIN=duplicate.test\n' >> "$OSSF_CONFIG"
expect_config_failure 'Duplicate configuration key'
cp "$original" "$OSSF_CONFIG"
# An apparent command remains data; SENTINEL detects accidental evaluation.
sed -i 's/^GITLAB_ROOT_PASSWORD=.*/GITLAB_ROOT_PASSWORD=literal$(touch SENTINEL) # quote" backslash\\ dollar$/' "$OSSF_CONFIG"
cd "$work"
ossf_load_config "$root"
test ! -e SENTINEL
[[ $GITLAB_ROOT_PASSWORD == 'literal$(touch SENTINEL) # quote" backslash\ dollar$' ]]
# Separate contracts: a Dojo PostgreSQL URL component and a SonarQube Java property.
[[ $(ossf_urlencode 'a$#'\''"\%+&= z') == 'a%24%23%27%22%5C%25%2B%26%3D%20z' ]]
[[ $(ossf_java_property 'a\ b') == 'a\\\ b' ]]
export OSSF_CONFIG=$work/missing.env
expect_config_failure 'Configuration missing or unreadable'
echo 'PASS: private config, generation/reuse, strict parsing, literal secrets, encoding.'
