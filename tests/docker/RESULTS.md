# Docker validation — 2026-09-27

## Shared configuration update

The configuration refactor was exercised with the real Ubuntu 26.04 ARM64
installers, using **test-only** private files rather than the workstation's
`config/ossf.env`:

- Docker installed and reran successfully with versions loaded from the file.
- GitLab's configured root password was verified against its actual user model;
  CE/Runner readiness, CI configuration validation and a second installation passed.
- SonarQube connected using a custom PostgreSQL user/database and a password with
  punctuation/spaces. Its configured administrator authenticated before and after
  the second run.
- Nexus's generated initial password was replaced through its REST API. The
  configured administrator authenticated before and after the second run.
- DefectDojo used a custom admin name and literal credentials, including a correctly
  encoded PostgreSQL URL. Initialization, all six persistent services, admin
  authentication and repeated installation passed. Its Compose wrapper also
  listed all six running services with the same central configuration.
- Central configuration and runtime credential checksums stayed unchanged. The
  tested secrets did not appear in the application installers' output.

Passwords containing spaces, dollar signs, quotes, backslashes, `#`, `%`, `+`, `&`
and `=` were exercised. GitLab rejected the first, predictable fixture containing punctuation under its own password-strength rules; the test was rerun with a random
password plus the same special characters and passed. No strength check was disabled.

Static/error tests also passed: private-file permissions, generation without
replacement, unique generated secrets, missing files, unknown/duplicate keys,
literal command-substitution text (never executed), URL/properties escaping,
changed saved-credential rejection, CLI validation and APT failure propagation.
ShellCheck 0.11.0 and Bash/YAML/XML syntax checks passed. Maven 3.9.16 successfully
resolved a dummy `CI_JOB_TOKEN` through the new `ci_settings.xml`; no registry
publication was performed.

The final DefectDojo rerun and output checks used the same assertions directly in
its retained test container. The remaining installation runs used `run.sh`.
The temporary containers were removed after validation, and the shared Docker
kernel's `vm.max_map_count` was restored to 262144. GitLab package configuration
was observed setting it to 1048576, so the harness now captures/restores it for
every integration target, after container removal; the cleanup path was retested.

## Modernized runtime baseline

Environment: macOS ARM host, Docker Desktop / Engine 29.7.2. Installations used
native `linux/arm64` Ubuntu **26.04.1 LTS** containers with systemd, based on
`ubuntu:26.04`, digest
`sha256:da6fc2be547864451aa253836dd926da33623312df4a9a243e35dc877c378a78`.
No host application packages were installed or upgraded. Temporary test containers
were removed after the checks; logs were retained outside the repository.

| Installer | Version exercised | Observed result |
| --- | --- | --- |
| Nexus | 3.96.3-01, bundled Temurin 21.0.11 | Official ARM archive and upstream SHA-256 verified; service active as `nexus`; status API HTTP 200. Second run passed with unchanged credential file. |
| GitLab CE + Runner | 19.4.1-ce.0 + 19.4.1-1 | Official Ubuntu Resolute packages; all readiness checks `ok`; both systemd services active and enabled. Second run passed with unchanged GitLab secrets. |
| SonarQube Community Build | 26.9.0.129388, OpenJDK 25.0.4.1, PostgreSQL 18.6 | Official ZIP downloaded and checksum verified; native service active as `sonar`; API `UP` with exact expected version. Repeated runs preserved the database password and instance ID. |
| Docker Engine + Compose | 29.8.1 + 5.5.1 | Official signed APT repository; installer reruns passed; service active/enabled; `hello-world` executed successfully in the test daemon. |
| DefectDojo | 3.3.200, PostgreSQL 18.6, Valkey 9.1.2 | Initializer exited 0; all six persistent services running; login HTTP 200; generated administrator password authenticated. Second run passed with unchanged credentials and encryption keys. |

SonarQube's JDBC keys occur once each, its properties file has mode 640 and its
password file mode 600. Elasticsearch bootstrap checks remained enabled. The
final script's higher-host-limit preservation and `TasksMax=8192` were exercised
in an additional successful rerun. The Docker VM's original `vm.max_map_count`
was restored to 262144 after stopping SonarQube.

## Checks executed

- ShellCheck 0.11.0, `bash -n`, help, malformed/missing arguments, invalid GitLab hostnames,
  root and systemd preconditions passed.
- Failure tests passed for a missing explicit local ZIP, invalid readiness timeout,
  incorrect SHA-256, missing Docker and mismatched existing SonarQube/Nexus markers.
- A simulated APT exit code 23 propagated through the Docker, Nexus, GitLab and
  SonarQube installers without falsely reporting success.
- All four CI examples parsed as YAML with valid script structures and were
  accepted by **GitLab 19.4.1's `Gitlab::Ci::YamlProcessor`**, including logical
  configuration validation.
- Official CI image manifests were checked. Native ARM containers executed
  Node.js **26.10.0**, Python **3.14.7**, Maven **3.9.16** with Temurin **25.0.4.1**,
  and Docker CLI **29.8.1**. The matching Docker DinD tag exists; the CI DinD job
  itself was not run through a registered GitLab Runner.

## Test environment adaptations

Ubuntu 26.04's `systemd-modules-load` cannot manage the Docker host kernel from a
container. It is masked in the test image alongside console/host-mount services.
Ubuntu's `55-map-count.conf` also sets a shared kernel limit at boot. Automatic
`systemd-sysctl` is therefore masked in the test image; failure tests were rerun
to verify that a normal test-container boot preserves the host's original value.

Docker 29's default containerd image store initially failed with a nested
OverlayFS mount error. The **test-only** daemon configuration now uses VFS and
disables the containerd image store. The production Docker installer does not
change the host's storage driver. The corrected daemon passed `hello-world`.

GitLab and Nexus were exercised with direct systemd-container invocations and the
same `verify.sh` assertions used by `run.sh`. SonarQube used `run.sh`, followed by
a direct rerun of the final service-limit change. DefectDojo's test resumed in its
fresh application container after correcting the nested Docker configuration.

## Limits

- Native amd64 hardware was unavailable. Scripts support its package/archive
  selection, but full amd64 runtime validation was not performed in this update.
- Tests use the Docker host kernel. Full VM reboot, TLS, backup/restore, upgrades
  from existing applications and production load were not exercised.
- Services were tested in separate containers. GitLab's internal port 8080 listener
  was observed; the shared-machine documentation therefore selects port 8088 for
  DefectDojo. The complete colocated deployment was not exercised.
- Runner registration, application-specific pipeline execution, registry publishing,
  scanners, SBOM generation and DefectDojo imports were not exercised. CI validation
  checks configuration, not those project-specific integrations.
- These are pinned releases available on the validation date. Later updates need
  compatibility review and fresh tests; the installers do not migrate old databases.
