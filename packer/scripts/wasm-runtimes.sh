#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

# Download the wasm containerd shims
curl -fsSL "${wasmedge_shim_download_url}" | tar -C /bin -xzf -
curl -fsSL "${spin_shim_download_url}" | tar -C /bin -xzf -

# Set the correct owner and permissions for the shim binary
chown root:root /bin/containerd-shim-wasmedge-v1
chown root:root /bin/containerd-shim-spin-v2
chmod 0750 /home/ec2-user/wasm-init.sh

# Delete the current service file and move the new one to the systemd directory for the nodeadm-run service
rm -f /etc/systemd/system/nodeadm-run.service
mv /home/ec2-user/nodeadm-run.service /etc/systemd/system/nodeadm-run.service

# Set the correct owner and permissions for the service file
chown root:root /etc/systemd/system/nodeadm-run.service
chmod 0644 /etc/systemd/system/nodeadm-run.service

# Reload the systemd daemon to pick up the new service file
systemctl daemon-reload