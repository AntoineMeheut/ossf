#!/bin/bash
# Generate disposable data inside the container to test all four applications.
# First argument: repository snapshot; optional second argument: test configuration path.
# Test credentials only: exercise literal punctuation, spaces and custom usernames.
set -euo pipefail
root=${1:?Repository snapshot}
config=${2:-$root/config/ossf.env}
bash "$root/scripts/init-config.sh" "$config" >/dev/null
# Keep the initializer's randomness to meet GitLab password-strength requirements, then add
# characters that expose escaping errors in Bash, URLs, dotenv or Java properties.
# Also customize SonarQube SQL names and the Dojo administrator to detect hardcoded values.
python3 - "$config" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
original = dict(line.split("=", 1) for line in path.read_text().splitlines() if line and not line.startswith("#"))
values = {
    "GITLAB_DOMAIN": "gitlab.ossf.test",
    "GITLAB_ROOT_EMAIL": "ops@ossf.test",
    "SONARQUBE_DB_USER": "ossf_sonar",
    "SONARQUBE_DB_NAME": "ossf_sonar_test",
    "DD_ADMIN_USER": "ossf_admin",
    "DD_ADMIN_MAIL": "ops@ossf.test",
}
for key in ("GITLAB_ROOT_PASSWORD", "SONARQUBE_ADMIN_PASSWORD", "SONARQUBE_DB_PASSWORD", "NEXUS_ADMIN_PASSWORD", "DD_ADMIN_PASSWORD", "DD_DATABASE_PASSWORD", "DD_SECRET_KEY"):
    values[key] = original[key] + ''' $#'"\\%+&= Z'''
path.write_text("\n".join(
    f"{line.split('=', 1)[0]}={values[line.split('=', 1)[0]]}"
    if '=' in line and line.split('=', 1)[0] in values else line
    for line in path.read_text().splitlines()
) + "\n")
PY
