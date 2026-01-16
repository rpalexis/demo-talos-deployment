#!/usr/bin/env bash
set -euo pipefail

# Configuration
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cleanup Logic
if [[ "${1:-}" == "clean" ]]; then
  ENV="${2:-dev}"
  OUT_DIR="${ROOT_DIR}/rendered_configs/${ENV}"
  BASE_DIR="${ROOT_DIR}/talos_base_config"
  
  echo "[CLEAN] Cleaning environment: ${ENV}"
  [[ -d "${OUT_DIR}" ]] && rm -rf "${OUT_DIR}"
  [[ -d "${BASE_DIR}" ]] && find "${BASE_DIR}" -mindepth 1 -not -name ".gitkeep" -delete
  
  echo "[OK] Done."
  exit 0
fi

ENV="${1:-dev}"
PATCH_DIR="${ROOT_DIR}/patches/envs/${ENV}"
BASE_DIR="${ROOT_DIR}/talos_base_config"
SECRETS_DIR="${ROOT_DIR}/secrets"
OUT_DIR="${ROOT_DIR}/rendered_configs/${ENV}"
APPLY_SCRIPT="${OUT_DIR}/apply.sh"

# Global variables for tracking
APPLY_CMDS=()
BOOTSTRAP_CMD=""
CP_IPS=()
ALL_IPS=()

# Load environment-specific variables
if [[ ! -f "${PATCH_DIR}/cluster.env" ]]; then
  echo "[ERROR] Environment '${ENV}' not found at ${PATCH_DIR}"
  exit 1
fi
source "${PATCH_DIR}/cluster.env"

mkdir -p "${OUT_DIR}"
mkdir -p "${BASE_DIR}"

echo "[INFO] Rendering Environment: ${ENV}"

# Secrets Decryption Logic (SOPS)
SECRETS_FILE="${SECRETS_DIR}/secrets.yaml"
TRAP_FILES=()

if [[ -f "${SECRETS_FILE}" ]] && grep -q "sops:" "${SECRETS_FILE}"; then
  echo "[INFO] Encrypted secrets detected. Decrypting with SOPS..."
  if ! command -v sops &> /dev/null; then
    echo "[ERROR] 'sops' not found. Please install it to decrypt secrets."
    exit 1
  fi
  DEC_SECRETS_FILE="${SECRETS_FILE}.dec"
  sops -d "${SECRETS_FILE}" > "${DEC_SECRETS_FILE}"
  SECRETS_FILE="${DEC_SECRETS_FILE}"
  TRAP_FILES+=("${DEC_SECRETS_FILE}")
fi

cleanup() {
  for f in "${TRAP_FILES[@]}"; do
    [[ -f "$f" ]] && rm -f "$f"
  done
}
trap cleanup EXIT ERR

# Generate talosconfig (client config) once per render
talosctl gen config "${CLUSTER_NAME}" "${CLUSTER_ENDPOINT}" \
  --with-secrets "${SECRETS_FILE}" \
  --talos-version "${TALOS_VERSION}" \
  --kubernetes-version "${KUBERNETES_VERSION}" \
  --output-types talosconfig \
  --output "${BASE_DIR}/talosconfig" \
  --force

# Helper to extract IP from patches
get_node_ip() {
  local NODE_DIR="$1"
  # Try to find an IP address in the patches (regex matches CIDR format)
  local IP=$(grep -rhEo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "${NODE_DIR}" | head -n1 || echo "")
  echo "${IP}"
}

render_node() {
  local ROLE="$1"        # controlplane | worker
  local NODE_NAME="$2"   # cp_1 | worker1
  local NODE_DIR="$3"    # patches/envs/dev/control_planes/cp_1

  echo "  * Rendering ${ROLE} ${NODE_NAME}"

  # Priority: Environmental common.yaml -> Node-specific patches
  PATCH_ARGS=()
  if [[ -f "${PATCH_DIR}/common.yaml" ]]; then
    PATCH_ARGS+=( --config-patch "@${PATCH_DIR}/common.yaml" )
  fi

  # Node-specific patches (ordered by filename)
  for patch in "${NODE_DIR}"/*.yaml; do
    [[ -e "$patch" ]] || continue
    PATCH_ARGS+=(--config-patch "@${patch}")
  done

  talosctl gen config "${CLUSTER_NAME}" "${CLUSTER_ENDPOINT}" \
    --with-secrets "${SECRETS_FILE}" \
    --talos-version "${TALOS_VERSION}" \
    --kubernetes-version "${KUBERNETES_VERSION}" \
    "${PATCH_ARGS[@]}" \
    --output-types "${ROLE}" \
    --output "${OUT_DIR}/${ROLE}-${NODE_NAME}.yaml" \
    --force

  # Track apply commands
  local NODE_IP=$(get_node_ip "${NODE_DIR}")
  local TARGET_IP="${NODE_IP:-<NODE_IP>}"
  local CONFIG_FILE="${OUT_DIR}/${ROLE}-${NODE_NAME}.yaml"
  
  APPLY_CMDS+=("talosctl apply-config --insecure --nodes ${TARGET_IP} --file ${CONFIG_FILE}")
  ALL_IPS+=("${TARGET_IP}")
  
  # Track control planes for endpoints and bootstrap
  if [[ "${ROLE}" == "controlplane" ]]; then
    CP_IPS+=("${TARGET_IP}")
    if [[ -z "${BOOTSTRAP_CMD}" ]]; then
      BOOTSTRAP_CMD="talosctl bootstrap --nodes ${TARGET_IP}"
    fi
  fi
}

# Control planes
if [[ -d "${PATCH_DIR}/control_planes" ]]; then
  for node_dir in "${PATCH_DIR}/control_planes/"*; do
    [[ -d "$node_dir" ]] || continue
    NODE_NAME="$(basename "${node_dir}")"
    render_node "controlplane" "${NODE_NAME}" "${node_dir}"
  done
fi

# Workers
if [[ -d "${PATCH_DIR}/workers" ]]; then
  for node_dir in "${PATCH_DIR}/workers/"*; do
    [[ -d "$node_dir" ]] || continue
    NODE_NAME="$(basename "${node_dir}")"
    render_node "worker" "${NODE_NAME}" "${node_dir}"
  done
fi

# Generate Apply Helper Script
cat <<EOF > "${APPLY_SCRIPT}"
#!/usr/bin/env bash
# Generated for environment: ${ENV}
export TALOSCONFIG="${BASE_DIR}/talosconfig"

echo "[INFO] Configuring talosctl..."
talosctl config endpoint $(printf "%s " "${CP_IPS[@]}")
talosctl config node $(printf "%s " "${ALL_IPS[@]}")

echo ""
echo "[INFO] Applying configurations..."
$(printf "%s\n" "${APPLY_CMDS[@]}")

echo ""
echo "[NEXT] Step: Bootstrap the cluster (only once)"
echo "   ${BOOTSTRAP_CMD}"
echo ""
echo "[CLEAN] To remove these sensitive files when done:"
echo "   ../../render.sh clean ${ENV}"
EOF
chmod +x "${APPLY_SCRIPT}"

echo "[OK] All configs rendered into ${OUT_DIR}"
echo ""
echo "[USAGE] To apply these configs, run:"
echo "   ./${OUT_DIR#$ROOT_DIR/}/apply.sh"
echo ""
echo "Or run these commands manually:"
printf "   %s\n" "${APPLY_CMDS[@]}"
echo ""
echo "Once nodes are up, bootstrap with:"
echo "   ${BOOTSTRAP_CMD}"
echo ""
echo "[CLEAN] To clean up rendered files later, run:"
echo "   ./render.sh clean ${ENV}"
