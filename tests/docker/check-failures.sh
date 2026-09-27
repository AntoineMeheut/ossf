#!/bin/bash
# Disposable VM simulation: these scenarios create fake markers in /opt and /etc.
# Run only through the test container, never directly on an installed VM.
# Run in a fresh systemd test container; simulate a package-manager failure.
set -euo pipefail
scripts=${1:?Path to the installer snapshot}
# Check the exit status, diagnostic and absence of a false success message.
expect_failure() {
    local expected=$1 message=$2 result=0
    shift 2
    "$@" > /var/tmp/ossf-failure-output 2>&1 || result=$?
    test "$result" = "$expected"
    grep -Fq "$message" /var/tmp/ossf-failure-output
    ! grep -q 'is ready\|is UP' /var/tmp/ossf-failure-output
}
export OSSF_CONFIG=$scripts/config/ossf.env
sonar=$scripts/install-sonarqube/sonarqube-ubuntu-server.sh
# Invalid input: no package/service should be installed before rejection.
expect_failure 1 'Provide a readable' bash "$sonar" --archive /missing.zip
cp "$OSSF_CONFIG" /var/tmp/ossf-invalid-config.env
sed -i 's/^WAIT_TIMEOUT=.*/WAIT_TIMEOUT=0/' /var/tmp/ossf-invalid-config.env
expect_failure 1 'WAIT_TIMEOUT must be' env OSSF_CONFIG=/var/tmp/ossf-invalid-config.env bash "$sonar"
printf 'not an archive\n' > /var/tmp/invalid.zip
expect_failure 1 'FAILED' bash "$sonar" --archive /var/tmp/invalid.zip
test ! -e /etc/ossf
test ! -e /opt/sonarqube
expect_failure 1 'Install Docker Engine' bash "$scripts/install-defectdojo/defectdojo-ubuntu-server.sh"

# A previous release marker must not be mistaken for a same-version rerun.
mkdir -p /opt/sonarqube /opt/nexus-3.96.3-01
printf '9.9.8.100196\n' > /opt/sonarqube/.ossf-managed
printf '3.80.0-06\n' > /opt/nexus-3.96.3-01/.ossf-managed
expect_failure 1 'upstream upgrade procedure' bash "$sonar"
expect_failure 1 'upstream upgrade procedure' bash "$scripts/install-nexus/nexus-ubuntu-server.sh"
rm /opt/sonarqube/.ossf-managed /opt/nexus-3.96.3-01/.ossf-managed
rmdir /opt/sonarqube /opt/nexus-3.96.3-01

# A different digest must stop a rerun before any accounts are changed.
mkdir -p /etc/ossf
printf 'different-configuration\n' > /etc/ossf/sonarqube-config.sha256
expect_failure 1 'credentials/settings differ' bash "$sonar"
rm /etc/ossf/sonarqube-config.sha256
rmdir /etc/ossf

for domain in 'https://gitlab.test' 'bad host' '-bad.test' 'bad..test' 'bad-.test' "bad'host"; do
    expect_failure 1 'Invalid domain' bash "$scripts/install-gitlab-ce/gitlab-ubuntu-server.sh" -d "$domain"
done

# Put a fake apt-get first in PATH to check that exit status 23 propagates unchanged.
# This replacement is limited to the test process and leaves the system binary untouched.
mkdir -p /var/tmp/ossf-command-fixtures
printf '#!/bin/bash\nexit 23\n' > /var/tmp/ossf-command-fixtures/apt-get
chmod +x /var/tmp/ossf-command-fixtures/apt-get
export PATH=/var/tmp/ossf-command-fixtures:$PATH
expect_failure 23 'installation stopped' bash "$scripts/install-nexus/nexus-ubuntu-server.sh"
expect_failure 23 'installation stopped' bash "$scripts/install-gitlab-ce/gitlab-ubuntu-server.sh" -d gitlab.test
expect_failure 23 'installation stopped' bash "$sonar"
expect_failure 23 'installation stopped' bash "$scripts/install-docker/docker-ubuntu-server.sh"
test ! -e /etc/systemd/system/nexus.service
test ! -e /etc/systemd/system/sonar.service
test ! -e /opt/sonarqube
echo 'PASS: missing archive/Docker, timeout validation, checksum failure and package-error propagation.'
