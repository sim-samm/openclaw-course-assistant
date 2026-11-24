#!/usr/bin/env bash
# Apply Gemini multi-model failover stack on the VM (provider registry + fallbacks).
# Does not touch Slack tokens. Restarts gateway.
#
# Usage (from experiments/openclaw-google/gcp):
#   ./scripts/start-vm.sh
#   ./vm/setup-model-stack.sh
#   ./vm/smoke-openclaw-models.sh   # optional verify
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GCP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=../scripts/lib.sh
source "$GCP_DIR/scripts/lib.sh"
load_phase0_env

VM_EXEC="$GCP_DIR/scripts/vm-exec.sh"
PATCH_LOCAL="$SCRIPT_DIR/model-failover.patch.json5"
PATCH_NAME="model-failover.patch.json5"
MODELS_REPLACE_LOCAL="$SCRIPT_DIR/google-provider-models.replace.json5"
MODELS_REPLACE_NAME="google-provider-models.replace.json5"

if [[ ! -x "$VM_EXEC" || ! -f "$PATCH_LOCAL" ]]; then
  echo "Missing vm-exec or $PATCH_LOCAL" >&2
  exit 1
fi

vm_copy_patch() {
  local patch_b64
  patch_b64=$(base64 < "$PATCH_LOCAL" | tr -d '\n')
  "$VM_EXEC" bash -s "$PATCH_NAME" "$patch_b64" <<'REMOTE'
set -euo pipefail
PATCH_NAME=$1
PATCH_B64=$2
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
CONTENT=$(printf '%s' "$PATCH_B64" | base64 -d)
printf '%s' "$CONTENT" > "$ROOT/$PATCH_NAME"
chmod 600 "$ROOT/$PATCH_NAME"
mkdir -p "$HOME/.openclaw"
printf '%s' "$CONTENT" > "$HOME/.openclaw/$PATCH_NAME"
chmod 600 "$HOME/.openclaw/$PATCH_NAME"
REMOTE
}

vm_config_patch() {
  "$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
PATCH_FILE="/home/node/.openclaw/model-failover.patch.json5"
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli config patch --file "$PATCH_FILE"
REMOTE
}

echo "==> Copy patches to VM"
vm_copy_patch
vm_copy_patch_file() {
  local local_file=$1
  local patch_name=$2
  local patch_b64
  patch_b64=$(base64 < "$local_file" | tr -d '\n')
  "$VM_EXEC" bash -s "$patch_name" "$patch_b64" <<'REMOTE'
set -euo pipefail
PATCH_NAME=$1
PATCH_B64=$2
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
CONTENT=$(printf '%s' "$PATCH_B64" | base64 -d)
printf '%s' "$CONTENT" > "$ROOT/$PATCH_NAME"
chmod 600 "$ROOT/$PATCH_NAME"
mkdir -p "$HOME/.openclaw"
printf '%s' "$CONTENT" > "$HOME/.openclaw/$PATCH_NAME"
chmod 600 "$HOME/.openclaw/$PATCH_NAME"
REMOTE
}
vm_copy_patch_file "$MODELS_REPLACE_LOCAL" "$MODELS_REPLACE_NAME"

echo "==> Apply config patch (api + primary/fallbacks)"
vm_config_patch

echo "==> Replace models.providers.google.models (drops retired preview entries)"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
REPLACE="/home/node/.openclaw/google-provider-models.replace.json5"
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli config patch --file "$REPLACE" \
  --replace-path models.providers.google
REMOTE

echo "==> Copy preview cleanup patch"
vm_copy_patch_file "$SCRIPT_DIR/model-cleanup-preview.patch.json5" "model-cleanup-preview.patch.json5"

echo "==> Remove stale 3.1-preview allowlist + gemini-flash-lite alias"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli models aliases remove gemini-flash-lite 2>&1 || true
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli config patch --file /home/node/.openclaw/model-cleanup-preview.patch.json5
REMOTE

# NOTE: intentionally skipping `openclaw models set <primary>`.
# In OpenClaw 2026.5.19 that CLI command applies a baked-in alias map that
# rewrites google/gemini-3.1-flash-lite -> google/gemini-3.1-flash-lite-preview
# inside agents.defaults.model.primary, overwriting the patch we just applied.
# The patch already sets agents.defaults.model.primary directly, which is the
# value the gateway runtime reads. See docs/MODEL_RECOVERY_PLAN.md.

echo "==> Restart gateway"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  up -d --no-build --force-recreate
sleep 14
curl -sS http://127.0.0.1:18789/healthz
REMOTE

echo "==> models status"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli models status 2>&1 | head -20
REMOTE

cat <<EOF

Done. Optional: ./vm/smoke-openclaw-models.sh via vm-exec.
Record stack date in journal.md. See docs/GEMINI_RATE_LIMITS.md.

EOF
