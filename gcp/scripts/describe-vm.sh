#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

load_phase0_env

gcloud compute instances describe "$GCE_VM_NAME" \
  --project="$GCP_PROJECT_ID" \
  --zone="$GCE_ZONE" \
  --format='table(name,status,machineType,zone,networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)'
