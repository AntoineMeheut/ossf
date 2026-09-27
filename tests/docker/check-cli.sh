#!/bin/bash
# Quick checks on the test workstation through Docker; no application installation.
# Runs inside the unprivileged lint container, without systemd or package installs.
set -euo pipefail
cd /workspace
# Follow the sourced library from the repository root, then check private configuration behavior.
shellcheck -x -P /workspace install-*/*.sh scripts/*.sh tests/docker/*.sh
bash tests/docker/check-config.sh /workspace
export OSSF_CONFIG=/tmp/ossf-cli-config.env
bash tests/docker/create-test-config.sh /workspace "$OSSF_CONFIG"
for script in install-*/*.sh; do
    bash -n "$script"
    bash "$script" --help >/dev/null
done

# Contract: the command must fail with the expected diagnostic, not for an unrelated reason.
expect_failure() {
    local message=$1
    shift
    if "$@" > /tmp/ossf-cli-output 2>&1; then
        echo "Expected failure: $*" >&2
        exit 1
    fi
    grep -Fq "$message" /tmp/ossf-cli-output || {
        cat /tmp/ossf-cli-output >&2
        exit 1
    }
}

gitlab=install-gitlab-ce/gitlab-ubuntu-server.sh
sonar=install-sonarqube/sonarqube-ubuntu-server.sh

# CLI parsing, root permission and systemd checks must fail before any system writes.
expect_failure 'Missing domain' bash "$gitlab" -d
expect_failure 'Missing ZIP path' bash "$sonar" --archive
for script in install-*/*.sh; do
    expect_failure 'argument' bash "$script" --invalid
    args=()
    [[ $script != "$gitlab" ]] || args=(-d gitlab.test)
    expect_failure 'Run this script as root' runuser -u nobody -- bash "$script" "${args[@]}"
    expect_failure 'running systemd is required' bash "$script" "${args[@]}"
done
test ! -e /etc/ossf
echo 'PASS: ShellCheck, Bash syntax, help, invalid input, root and systemd checks.'

# Parse YAML/XML locally; full GitLab validation lives in check-gitlab-ci.rb.
# Also check script types: an incorrectly quoted YAML colon can create a dictionary.
python3 - <<'PYTHON'
from pathlib import Path
import yaml
import xml.etree.ElementTree as ET
ET.parse("samples-gitlab-ci/ci_settings.xml")
for path in Path("samples-gitlab-ci").glob("*.yml"):
    config = yaml.safe_load(path.read_text())
    assert isinstance(config, dict), path
    for name, job in config.items():
        if isinstance(job, dict) and "script" in job:
            assert isinstance(job["script"], (str, list)), (path, name)
            if isinstance(job["script"], list):
                assert all(isinstance(line, str) for line in job["script"]), (path, name)
    print(f"PASS: YAML and script structure: {path}")
PYTHON
