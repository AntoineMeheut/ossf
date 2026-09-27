#!/bin/bash
# Administration workstation: generate secrets once, then copy the file to the VMs.
# Create once, on the administration workstation; copy the same file to the VMs.
set -euo pipefail
umask 077
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    echo "Usage: bash $0 [output-file] (default: config/ossf.env)"
    exit 0
fi
[[ $# -le 1 ]] || { echo 'Too many arguments.' >&2; exit 1; }
# Reruns preserve the existing configuration, including when the path is a symlink.
output=${1:-$root/config/ossf.env}
[[ ! -e $output && ! -L $output ]] || { echo "Configuration already exists; it was not changed: $output"; exit 0; }
command -v openssl >/dev/null || { echo 'OpenSSL is required to generate credentials.' >&2; exit 1; }
mkdir -p "$(dirname "$output")"
# Keep the temporary file private (umask 077) and on the same filesystem as the target.
temporary=$(mktemp "$(dirname "$output")/.ossf-config.XXXXXX")
trap 'rm -f -- "$temporary"' EXIT
# Copy the template comments as well. Populate only secrets that are left empty.
# Each OpenSSL call produces an independent value; the password prefix provides
# the required character classes without replacing the random portion.
# AES: 16 bytes encoded as hexadecimal yield the 32 characters expected by Dojo.
while IFS= read -r line || [[ -n $line ]]; do
    case $line in
        GITLAB_ROOT_PASSWORD=|SONARQUBE_ADMIN_PASSWORD=|NEXUS_ADMIN_PASSWORD=|DD_ADMIN_PASSWORD=)
            line="${line}Aa9!$(openssl rand -hex 24)" ;;
        SONARQUBE_DB_PASSWORD=|DD_DATABASE_PASSWORD=) line="$line$(openssl rand -hex 24)" ;;
        DD_SECRET_KEY=) line="$line$(openssl rand -hex 32)" ;;
        DD_CREDENTIAL_AES_256_KEY=) line="$line$(openssl rand -hex 16)" ;;
    esac
    printf '%s\n' "$line" >> "$temporary"
done < "$root/config/ossf.env.example"
# Atomic creation without replacing an existing file, including a concurrent run.
# The hard link fails if another run created the target; EXIT removes the temporary file.
ln "$temporary" "$output"
echo "Private configuration created: $output"
echo 'Edit the hostname/email addresses, then copy this same file to each VM (mode 600).'
