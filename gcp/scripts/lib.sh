#!/usr/bin/env bash
# Shared helpers for Phase 0 GCE scripts. Source from other scripts in this directory.
set -euo pipefail

_openclaw_gcp_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

load_phase0_env() {
  local root
  root="$(_openclaw_gcp_root)"
  local env_file="$root/phase0.env"
  if [[ ! -f "$env_file" ]]; then
    echo "Missing $env_file" >&2
    echo "Copy phase0.env.example to phase0.env and set GCP_PROJECT_ID, zone, VM name, etc." >&2
    exit 1
  fi
  set -a
  # shellcheck source=/dev/null
  source "$env_file"
  set +a

  : "${GCP_PROJECT_ID:?GCP_PROJECT_ID must be set in phase0.env}"
  : "${GCE_ZONE:?GCE_ZONE must be set in phase0.env}"
  : "${GCE_VM_NAME:?GCE_VM_NAME must be set in phase0.env}"
  : "${GCE_MACHINE_TYPE:?GCE_MACHINE_TYPE must be set in phase0.env}"
  : "${GCE_BOOT_DISK_GB:?GCE_BOOT_DISK_GB must be set in phase0.env}"
  : "${GCE_IMAGE_FAMILY:?GCE_IMAGE_FAMILY must be set in phase0.env}"
  : "${GCE_IMAGE_PROJECT:?GCE_IMAGE_PROJECT must be set in phase0.env}"
  : "${LOCAL_TUNNEL_PORT:?LOCAL_TUNNEL_PORT must be set in phase0.env}"
  : "${GCE_GATEWAY_PORT:?GCE_GATEWAY_PORT must be set in phase0.env}"
  GCE_USE_IAP_TUNNEL="${GCE_USE_IAP_TUNNEL:-false}"
}
