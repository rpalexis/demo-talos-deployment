#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${ROOT_DIR}/talos_base_config"
SECRETS_DIR="${ROOT_DIR}/secrets"
PATCH_DIR="${ROOT_DIR}/patches"
OUT_DIR="${ROOT_DIR}/rendered_configs"

source "${ROOT_DIR}/cluster.env"
mkdir -p "${OUT_DIR}"

# Generate talosconfig (client config) once per render
talosctl gen config "${CLUSTER_NAME}" "${CLUSTER_ENDPOINT}" \
  --with-secrets "${SECRETS_DIR}/secrets.yaml" \
  --talos-version "${TALOS_VERSION}" \
  --kubernetes-version "${KUBERNETES_VERSION}" \
  --output-types talosconfig \
  --output "${BASE_DIR}/talosconfig"

render_node() {
  local ROLE="$1"        # controlplane | worker
  local NODE_NAME="$2"   # cp_1 | worker1
  local NODE_DIR="$3"    # patches/control_planes/cp_1

  echo "▶ Rendering ${ROLE} ${NODE_NAME}"

  PATCH_ARGS=( --config-patch "@${PATCH_DIR}/common.yaml" )

  # Node-specific patches (ordered by filename)
  for patch in "${NODE_DIR}"/*.yaml; do
    PATCH_ARGS+=(--config-patch "@${patch}")
  done

  talosctl gen config "${CLUSTER_NAME}" "${CLUSTER_ENDPOINT}" \
    --with-secrets "${SECRETS_DIR}/secrets.yaml" \
    --talos-version "${TALOS_VERSION}" \
    --kubernetes-version "${KUBERNETES_VERSION}" \
    "${PATCH_ARGS[@]}" \
    --output-types "${ROLE}" \
    --output "${OUT_DIR}/${ROLE}-${NODE_NAME}.yaml"
}

# Control planes
for node_dir in "${PATCH_DIR}/control_planes/"*; do
  NODE_NAME="$(basename "${node_dir}")"
  render_node "controlplane" "${NODE_NAME}" "${node_dir}"
done

# Workers
for node_dir in "${PATCH_DIR}/workers/"*; do
  NODE_NAME="$(basename "${node_dir}")"
  render_node "worker" "${NODE_NAME}" "${node_dir}"
done

echo "✔ All configs rendered into ${OUT_DIR}"
