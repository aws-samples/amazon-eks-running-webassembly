#!/bin/bash

# Import the needed config for containerd into the already present config file
cat /home/ec2-user/containerd-config.toml >> /etc/containerd/config.toml

# Restart and enable containerd and kubelet
systemctl restart containerd
systemctl enable containerd
systemctl restart kubelet
systemctl enable kubelet

# Disable nodeadm services
systemctl disable nodeadm-config.service
systemctl disable nodeadm-run.service