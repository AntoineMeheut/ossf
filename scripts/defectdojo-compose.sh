#!/bin/bash
# VM 1: maintenance entry point (ps, logs, stop...) for the DefectDojo stack.
# INSTALL_DIR and DD_* variables come from the same file used during installation.
# Operate the installed stack with the same private configuration as the installer.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/config.sh
. "$root/scripts/config.sh"
ossf_load_config "$root"
ossf_defectdojo_environment
cd "$INSTALL_DIR"
# /dev/null disables dotenv loading, preserving exported values literally.
# .ossf.env is a verification copy; do not source it or pass it to Compose.
# exec lets the caller interact directly with Compose, preserving signals and exit status.
exec docker compose --project-name ossf-defectdojo --env-file /dev/null \
    -f docker-compose.yml -f docker-compose.ossf.yml "$@"
