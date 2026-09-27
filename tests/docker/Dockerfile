# Test image for all three VMs; this file does not define a production deployment.
# Keep the Ubuntu version consistent with installer prerequisites.
FROM ubuntu:26.04

# systemd supports integration tests; ShellCheck/Python/YAML support static checks.
# Services specific to physical machines are masked inside the container.
ENV DEBIAN_FRONTEND=noninteractive container=docker
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       systemd systemd-sysv dbus sudo ca-certificates curl git openssl \
       iproute2 procps shellcheck python3 python3-yaml \
    && rm -rf /var/lib/apt/lists/* \
    && systemctl mask systemd-modules-load.service systemd-remount-fs.service getty.target \
       console-getty.service systemd-logind.service

# Keep Ubuntu default sysctls from modifying the shared Docker host kernel.
# Installation scripts can still modify kernel settings; run.sh handles restoration.
RUN systemctl mask systemd-sysctl.service
# Shut down systemd cleanly; it runs as PID 1 during integration tests.
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
