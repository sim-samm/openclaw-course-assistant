#!/usr/bin/env bash
# Forward local port LOCAL_TUNNEL_PORT to the gateway Control UI on the VM (loopback:GCE_GATEWAY_PORT).
# Blocks until you Ctrl+C. Open http://127.0.0.1:${LOCAL_TUNNEL_PORT}/ in a browser after the gateway is running.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

load_phase0_env

iap=()
if [[ "${GCE_USE_IAP_TUNNEL:-false}" == "true" ]]; then
  iap=(--tunnel-through-iap)
fi

echo "Starting SSH tunnel: localhost:${LOCAL_TUNNEL_PORT} -> ${GCE_VM_NAME} 127.0.0.1:${GCE_GATEWAY_PORT}"
echo "Press Ctrl+C to stop."

gcloud compute ssh "$GCE_VM_NAME" \
  --project="$GCP_PROJECT_ID" \
  --zone="$GCE_ZONE" \
  "${iap[@]}" \
  -- -N -L "${LOCAL_TUNNEL_PORT}:127.0.0.1:${GCE_GATEWAY_PORT}"
