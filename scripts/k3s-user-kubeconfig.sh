#!/usr/bin/env bash
set -euo pipefail

# Wait for k3s to generate the config
until test -f /etc/rancher/k3s/k3s.yaml; do
  sleep 1
done

# Get real user (even if running via sudo)
TARGET_USER=${SUDO_USER:-$USER}
TARGET_UID=${SUDO_UID:-$(id -u)}
TARGET_GID=${SUDO_GID:-$(id -g)}
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# Copy and setup permissions for the real user
mkdir -p "${TARGET_HOME}/.kube"
cp /etc/rancher/k3s/k3s.yaml "${TARGET_HOME}/.kube/config"
chown "${TARGET_UID}:${TARGET_GID}" "${TARGET_HOME}/.kube/config"
chmod 600 "${TARGET_HOME}/.kube/config"
