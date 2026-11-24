#!/usr/bin/env bash
# Create the OpenClaw gateway VM (Debian + empty disk). OpenClaw install happens on-VM per upstream docs.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

load_phase0_env

if gcloud compute instances describe "$GCE_VM_NAME" --zone="$GCE_ZONE" --project="$GCP_PROJECT_ID" &>/dev/null; then
  echo "VM $GCE_VM_NAME already exists in $GCE_ZONE — skipping create."
  exit 0
fi

gcloud compute instances create "$GCE_VM_NAME" \
  --project="$GCP_PROJECT_ID" \
  --zone="$GCE_ZONE" \
  --machine-type="$GCE_MACHINE_TYPE" \
  --boot-disk-size="${GCE_BOOT_DISK_GB}GB" \
  --image-family="$GCE_IMAGE_FAMILY" \
  --image-project="$GCE_IMAGE_PROJECT"

echo "Created $GCE_VM_NAME. Wait 1–2 minutes for SSH keys, then: ./scripts/ssh-tunnel.sh (separate terminal) or ./scripts/vm-exec.sh …"
