#!/usr/bin/env bash
# Enable APIs required for a minimal GCE + SSH Phase 0 path.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

load_phase0_env

gcloud services enable compute.googleapis.com --project="$GCP_PROJECT_ID"
echo "Enabled compute.googleapis.com on project $GCP_PROJECT_ID"
