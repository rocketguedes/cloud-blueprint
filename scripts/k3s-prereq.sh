#!/usr/bin/env bash
set -euo pipefail

# Enable IPv4/IPv6 forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Persist settings
cat <<EOF | tee /etc/sysctl.d/99-k3s.conf > /dev/null
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
