#!/bin/bash
# Check after installation AND rerun inside the container simulating the relevant VM.
# Expected versions are deliberately pinned; update them together with the installers.
# Runs in an installed test container. Does not print any passwords.
set -euo pipefail
# shellcheck source=scripts/config.sh
. /opt/ossf-scripts/scripts/config.sh
ossf_load_config /opt/ossf-scripts
case ${1:?Specify nexus, sonarqube, gitlab or defectdojo} in
    nexus)
        # VM 3: version, effective Unix account, service and access to a protected API.
        test "$(cat /opt/nexus-3.96.3-01/.ossf-managed)" = 3.96.3-01
        systemctl is-enabled --quiet nexus
        systemctl is-active --quiet nexus
        test "$(ps -o user= -p "$(systemctl show -p MainPID --value nexus)" | xargs)" = nexus
        curl -fsS -o /dev/null http://127.0.0.1:8081/service/rest/v1/status
        ossf_curl "$NEXUS_ADMIN_USER" "$NEXUS_ADMIN_PASSWORD" --fail --output /dev/null \
            http://127.0.0.1:8081/service/rest/v1/security/users
        ;;
    sonarqube)
        # VM 2: local PostgreSQL, JDK, UP status and WEB access; also check the JDBC files.
        test "$(cat /opt/sonarqube/.ossf-managed)" = 26.9.0.129388
        /usr/lib/jvm/java-25-openjdk-"$(dpkg --print-architecture)"/bin/javac --version
        pg_lsclusters --no-header | grep -Eq '^18 +main +5432 +online'
        systemctl is-enabled --quiet sonar
        systemctl is-active --quiet sonar
        test "$(ps -o user= -p "$(systemctl show -p MainPID --value sonar)" | xargs)" = sonar
        curl -fsS http://127.0.0.1:9000/api/system/status | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "UP" and d["version"] == "26.9.0.129388"'
        ossf_curl "$SONARQUBE_ADMIN_USER" "$SONARQUBE_ADMIN_PASSWORD" --fail \
            http://127.0.0.1:9000/api/authentication/validate | python3 -c 'import json,sys; assert json.load(sys.stdin)["valid"]'
        test "$(cat /etc/ossf/sonarqube-db-password)" = "$SONARQUBE_DB_PASSWORD"
        test "$(stat -c %a /etc/ossf/sonarqube-db-password)" = 600
        test "$(stat -c %a /opt/sonarqube/conf/sonar.properties)" = 640
        test "$(grep -c '^sonar.jdbc.url=' /opt/sonarqube/conf/sonar.properties)" = 1
        test "$(grep -c '^sonar.jdbc.username=' /opt/sonarqube/conf/sonar.properties)" = 1
        test "$(grep -c '^sonar.jdbc.password=' /opt/sonarqube/conf/sonar.properties)" = 1
        ! grep -q 'bootstrap check failure' /opt/sonarqube/logs/es.log
        ;;
    gitlab)
        # VM 1: services and overall readiness; the installer already checks the password in Rails.
        test "$(dpkg-query -W -f='${Version}' gitlab-ce)" = 19.4.1-ce.0
        test "$(dpkg-query -W -f='${Version}' gitlab-runner)" = 19.4.1-1
        systemctl is-enabled --quiet gitlab-runsvdir gitlab-runner
        systemctl is-active --quiet gitlab-runsvdir gitlab-runner
        curl -fsS 'http://127.0.0.1/-/readiness?all=1' | python3 -c 'import json,sys; assert json.load(sys.stdin)["status"] == "ok"'
        test -s /etc/gitlab/gitlab-secrets.json
        test "$(stat -c %a /etc/ossf/gitlab-domain)" = 600
        ;;
    defectdojo)
        # VM 1: initializer completed successfully, followed by six running persistent services.
        cd /opt/defectdojo
        test "$(cat .ossf-version)" = 3.3.200
        test "$(git describe --tags --exact-match)" = 3.3.200
        test "$(stat -c %a .ossf.env)" = 600
        ossf_defectdojo_environment
        compose=(docker compose -p ossf-defectdojo --env-file /dev/null -f docker-compose.yml -f docker-compose.ossf.yml)
        initializer=$("${compose[@]}" ps -a -q initializer)
        test "$(docker inspect --format '{{.State.Status}} {{.State.ExitCode}}' "$initializer")" = 'exited 0'
        for service in nginx uwsgi celerybeat celeryworker postgres valkey; do
            id=$("${compose[@]}" ps -q "$service")
            test -n "$id"
            test "$(docker inspect --format '{{.State.Running}}' "$id")" = true
        done
        curl -fsS -o /dev/null "http://127.0.0.1:$DD_PORT/login"
        # Check that the generated administrator password really authenticates.
        # An accessible login page is insufficient: authenticate the account in Django.
        "${compose[@]}" exec -T -e DD_ADMIN_PASSWORD -e DD_ADMIN_USER uwsgi python manage.py shell -c \
            'import os; from django.contrib.auth import authenticate; u = authenticate(username=os.environ["DD_ADMIN_USER"], password=os.environ["DD_ADMIN_PASSWORD"]); assert u is not None and u.is_superuser; print("Administrator authentication: OK")'
        ;;
    *) echo "Unknown service: $1" >&2; exit 1 ;;
esac
echo "PASS: $1 runtime verification."
