#!/usr/bin/env bash
# Delete the VM and attached boot disk (destructive). Review static IPs separately in console.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

load_phase0_env

read -r -p "Delete VM $GCE_VM_NAME in $GCE_ZONE? Type yes: " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

gcloud compute instances delete "$GCE_VM_NAME" \
  --project="$GCP_PROJECT_ID" \
  --zone="$GCE_ZONE" \
  --quiet
echo "Deleted $GCE_VM_NAME"
