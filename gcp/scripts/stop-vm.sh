#!/usr/bin/env bash
# Stop the VM to save compute cost (disk still billed unless deleted).
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

load_phase0_env

gcloud compute instances stop "$GCE_VM_NAME" \
  --project="$GCP_PROJECT_ID" \
  --zone="$GCE_ZONE"
echo "Stopped $GCE_VM_NAME"
