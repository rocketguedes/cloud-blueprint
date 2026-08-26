#!/usr/bin/env bash
# K3s and Cilium full reset script
set -euo pipefail

# Clean Cilium interfaces
ip link delete cilium_host 2>/dev/null || true
ip link delete cilium_net 2>/dev/null || true
ip link delete cilium_vxlan 2>/dev/null || true

# Clean Cilium iptables
(iptables-save 2>/dev/null | grep -iv cilium | iptables-restore 2>/dev/null) || true
(ip6tables-save 2>/dev/null | grep -iv cilium | ip6tables-restore 2>/dev/null) || true

# Uninstall K3s
/usr/local/bin/k3s-killall.sh || true
/usr/local/bin/k3s-uninstall.sh || true

# Deep clean rancher files
rm -rf /var/lib/rancher/k3s/*
rm -f /usr/local/bin/k3s-install.sh
rm -f /etc/rancher/k3s/config.yaml

# Get real user (even if running via sudo)
TARGET_USER=${SUDO_USER:-$USER}
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# Clean remote user kubeconfig
rm -f "${TARGET_HOME}/.kube/config"
