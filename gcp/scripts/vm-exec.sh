#!/usr/bin/env bash
# Run a remote command on the VM: ./vm-exec.sh -- bash -lc 'uname -a'
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

load_phase0_env

iap=()
if [[ "${GCE_USE_IAP_TUNNEL:-false}" == "true" ]]; then
  iap=(--tunnel-through-iap)
fi

gcloud compute ssh "$GCE_VM_NAME" \
  --project="$GCP_PROJECT_ID" \
  --zone="$GCE_ZONE" \
  "${iap[@]}" \
  -- "$@"
