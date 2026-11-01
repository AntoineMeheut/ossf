#!/bin/sh
set -eu
set -- "-Dsonar.projectKey=$SONAR_PROJECT_KEY" "-Dsonar.scm.revision=$CI_COMMIT_SHA" \
  "-Dsonar.scanner.metadataFilePath=$CI_PROJECT_DIR/reports/sonar-task.txt" \
  "-Dsonar.java.source=$JAVA_SOURCE"
# An application with no external dependencies must not pass an empty JAR glob.
if [ -d target/dependency ] && [ -n "$(find target/dependency -name '*.jar' -print -quit)" ]; then
  set -- "$@" '-Dsonar.java.libraries=target/dependency/*.jar' '-Dsonar.java.test.libraries=target/dependency/*.jar'
fi
sonar-scanner "$@"
