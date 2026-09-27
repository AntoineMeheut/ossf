# Installer tests in Docker

Run from the repository root with Bash and a working Docker Engine. Tests build
`ubuntu:26.04` with systemd and run the actual installers, package managers,
databases and applications. They publish no host ports and never mount the host
Docker socket into a test container.

```sh
bash tests/docker/run.sh lint
bash tests/docker/run.sh failures
bash tests/docker/run.sh nexus
bash tests/docker/run.sh gitlab
bash tests/docker/run.sh defectdojo
bash tests/docker/run.sh sonarqube
# Or run all targets sequentially:
bash tests/docker/run.sh all
```

Allow several GB of downloads, tens of GB of free disk and enough memory for the
largest service (especially GitLab). SonarQube downloads the official ZIP by
default. To reuse a local official archive:

```sh
SONARQUBE_ARCHIVE=/absolute/path/sonarqube-26.9.0.129388.zip \
  bash tests/docker/run.sh sonarqube
```

Tests generate their own private configuration and never copy the host's
`config/ossf.env`. Their passwords contain literal spaces, quotes, `$`, backslashes
and URL punctuation; SonarQube uses a custom database name/user and DefectDojo a
custom admin name.

The integration containers use `--privileged --cgroupns private` for systemd.
The test image masks services that require control of the host kernel or console,
including automatic systemd sysctls. Installers and package scripts can still
change the shared memory-map limit; the runner restores it after container removal.
DefectDojo's container installs Docker Engine and Compose using the production
installer, runs that installer twice, and runs `hello-world` before testing the
application. Its Docker daemon and volumes are isolated inside the test container.
Only this test daemon uses VFS with the containerd image store disabled, because
Docker 29's nested OverlayFS mounts cannot run on an OverlayFS root filesystem.

Use a dedicated Docker environment. SonarQube and package scripts can change
`vm.max_map_count` in the Docker host's shared kernel. The runner records it before
every integration test and restores it after removing the container. Run tests
sequentially, without concurrent workloads that change that setting.

`lint` runs ShellCheck, Bash syntax, CLI checks and YAML parsing. `failures` verifies invalid
inputs, a missing local archive, checksum errors, missing Docker and propagation
of an injected APT failure. Only this failure test mocks the package manager.

Runtime tests snapshot each installer, check readiness and service configuration,
run it a second time, and assert that the central configuration and runtime
credential file are unchanged. Administrator authentication is checked for
GitLab, SonarQube, Nexus and DefectDojo. The
SonarQube rerun omits the archive. DefectDojo verifies administrator authentication
and successful initialization, as well as all six persistent services.

The GitLab test installs CE and Runner and validates the CI examples through
GitLab's own YAML processor. It does not register a Runner or run project pipelines. Tests on one CPU architecture do not validate the other one.
Docker shares a kernel with its host; these tests do not replace native VM boot,
networking, TLS, backup/restore or production-load validation.

Containers are removed on success or failure and logs copied to the printed
temporary directory. Options:

- `TEST_LOG_DIR=/path`: choose the logs' parent directory.
- `TEST_KEEP_CONTAINER=1`: retain containers for diagnosis, including their kernel
  setting changes; remove retained containers and restore the original shared
  kernel settings afterwards.
- `TEST_PLATFORM=linux/amd64` or `linux/arm64`: choose the platform. Prefer native
  hardware; emulation can fail Elasticsearch's seccomp checks. Do not disable them.

See [RESULTS.md](RESULTS.md) for the versions and checks actually executed.
