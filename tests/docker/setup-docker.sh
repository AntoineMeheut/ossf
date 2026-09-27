#!/bin/bash
# Simulate VM 1 only, inside the privileged test container.
# The nested Docker daemon hosts DefectDojo without access to the workstation's Docker socket.
# Only used in the disposable privileged container; no host Docker socket.
set -euo pipefail
# Docker 29 defaults to the containerd image store. Nested overlay mounts are
# unsupported on this container's overlay rootfs; use VFS only in this test VM.
# VFS works around nested overlay mount limitations; do not apply this setting to deployed VMs.
install -d /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{"storage-driver":"vfs","features":{"containerd-snapshotter":false}}
EOF
# Two runs verify that rerunning leaves Docker working at the same version.
bash /opt/ossf-scripts/install-docker/docker-ubuntu-server.sh
bash /opt/ossf-scripts/install-docker/docker-ubuntu-server.sh
systemctl is-enabled --quiet docker
systemctl is-active --quiet docker
docker run --rm hello-world
