#!/usr/bin/env bash
# Generates /etc/rancher/k3s/config.yaml from environment variables.
# Required env vars: K3S_ADVERTISE_ADDRESS, K3S_NODE_IPS,
#                    K3S_NODE_EXTERNAL_IPS, API_ENDPOINT
set -euo pipefail

cat <<EOF
cluster-init: true
disable-kube-proxy: true
disable-network-policy: true
disable:
  - "servicelb"
  - "traefik"
flannel-backend: "none"
advertise-address: "${K3S_ADVERTISE_ADDRESS}"
node-ip: "${K3S_NODE_IPS}"
node-external-ip: "${K3S_NODE_EXTERNAL_IPS}"
cluster-cidr: "10.42.0.0/16,fd42::/56"
service-cidr: "10.43.0.0/16,fd43::/112"
tls-san:
  - "10.200.200.1"
  - "fdc9:281f:04d7:9ee9::1"
  - "100.64.0.3"
  - "fd7a:115c:a1e0::3"
  - "${API_ENDPOINT}"
kube-apiserver-arg:
  - "oidc-issuer-url=https://accounts.guedescloud.com.br"
  - "oidc-client-id=headlamp"
  - "oidc-username-claim=sub"
  - "oidc-username-prefix=-"
  - "oidc-groups-claim=groups"
  - "oidc-groups-prefix="
EOF
