#!/usr/bin/env bash
# Configure Slack Socket Mode on the OpenClaw VM via vm-exec (golden path).
# Requires SLACK_APP_TOKEN and SLACK_BOT_TOKEN in the environment (see SLACK_APP_SETUP.md).
# Recommended: GEMINI_API_KEY (and optionally GOOGLE_API_KEY) for class demos.
# Optional: ANTHROPIC_API_KEY or OPENAI_API_KEY appended to ~/openclaw/.env.
#
# Usage (from experiments/openclaw-google/gcp):
#   export SLACK_APP_TOKEN='xapp-...'
#   export SLACK_BOT_TOKEN='xoxb-...'
#   export GEMINI_API_KEY='...'
#   ./vm/setup-slack-socket.sh
#   ./vm/setup-google-genai-proxy.sh && ./vm/setup-model-stack.sh   # required after token/workspace changes
#
# Prep only (plugin + patch files, no Slack tokens):
#   ./vm/setup-slack-socket.sh --prep-only
set -euo pipefail

PREP_ONLY=false
if [[ "${1:-}" == "--prep-only" ]]; then
  PREP_ONLY=true
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GCP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=../scripts/lib.sh
source "$GCP_DIR/scripts/lib.sh"
load_phase0_env

VM_EXEC="$GCP_DIR/scripts/vm-exec.sh"
SOCKET_PATCH_LOCAL="$SCRIPT_DIR/slack-socket.patch.json5.example"
SOCKET_PATCH_NAME="slack.socket.patch.json5"
POLICY_PATCH_LOCAL="$SCRIPT_DIR/slack-channel-policy.patch.json5"
POLICY_PATCH_NAME="slack-channel-policy.patch.json5"
MODEL_PATCH_LOCAL="$SCRIPT_DIR/model-failover.patch.json5"
MODEL_PATCH_NAME="model-failover.patch.json5"

if [[ ! -x "$VM_EXEC" ]]; then
  echo "Missing vm-exec: $VM_EXEC" >&2
  exit 1
fi

if [[ "$PREP_ONLY" != "true" ]]; then
  if [[ -z "${SLACK_APP_TOKEN:-}" || -z "${SLACK_BOT_TOKEN:-}" ]]; then
    echo "Set SLACK_APP_TOKEN and SLACK_BOT_TOKEN, or run with --prep-only." >&2
    echo "See vm/SLACK_APP_SETUP.md" >&2
    exit 1
  fi
fi

vm_copy_patch() {
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

vm_set_env() {
  local key=$1
  local val=$2
  local val_b64
  val_b64=$(printf '%s' "$val" | base64 | tr -d '\n')
  "$VM_EXEC" bash -s "$key" "$val_b64" <<'REMOTE'
set -euo pipefail
KEY=$1
VAL_B64=$2
VAL=$(printf '%s' "$VAL_B64" | base64 -d)
ENV_FILE="$HOME/openclaw/.env"
python3 - "$ENV_FILE" "$KEY" "$VAL" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
key = sys.argv[2]
val = sys.argv[3]
lines = path.read_text().splitlines() if path.exists() else []
out, found = [], False
for line in lines:
    if line.startswith(key + "="):
        out.append(f"{key}={val}")
        found = True
    else:
        out.append(line)
if not found:
    out.append(f"{key}={val}")
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text("\n".join(out) + "\n")
path.chmod(0o600)
PY
REMOTE
}

vm_config_patch() {
  local patch_file=$1
  "$VM_EXEC" bash -s "$patch_file" <<'REMOTE'
set -euo pipefail
PATCH_FILE=$1
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli config patch --file "$PATCH_FILE" --dry-run
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli config patch --file "$PATCH_FILE"
REMOTE
}

echo "==> Copy config patches to VM (~/openclaw and ~/.openclaw for CLI mount)"
vm_copy_patch "$SOCKET_PATCH_LOCAL" "$SOCKET_PATCH_NAME"
vm_copy_patch "$POLICY_PATCH_LOCAL" "$POLICY_PATCH_NAME"
vm_copy_patch "$MODEL_PATCH_LOCAL" "$MODEL_PATCH_NAME"

SOCKET_PATCH_IN_CONTAINER="/home/node/.openclaw/$SOCKET_PATCH_NAME"
POLICY_PATCH_IN_CONTAINER="/home/node/.openclaw/$POLICY_PATCH_NAME"
MODEL_PATCH_IN_CONTAINER="/home/node/.openclaw/$MODEL_PATCH_NAME"

if [[ "$PREP_ONLY" != "true" ]]; then
  echo "==> Append Slack tokens to ~/openclaw/.env (VM only)"
  vm_set_env SLACK_APP_TOKEN "$SLACK_APP_TOKEN"
  vm_set_env SLACK_BOT_TOKEN "$SLACK_BOT_TOKEN"
fi

if [[ -n "${GEMINI_API_KEY:-}" ]]; then
  echo "==> Append GEMINI_API_KEY to ~/openclaw/.env"
  vm_set_env GEMINI_API_KEY "$GEMINI_API_KEY"
fi

if [[ -n "${GOOGLE_API_KEY:-}" ]]; then
  echo "==> Append GOOGLE_API_KEY to ~/openclaw/.env"
  vm_set_env GOOGLE_API_KEY "$GOOGLE_API_KEY"
fi

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "==> Append ANTHROPIC_API_KEY to ~/openclaw/.env"
  vm_set_env ANTHROPIC_API_KEY "$ANTHROPIC_API_KEY"
elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
  echo "==> Append OPENAI_API_KEY to ~/openclaw/.env"
  vm_set_env OPENAI_API_KEY "$OPENAI_API_KEY"
fi

echo "==> Install @openclaw/slack plugin on VM"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
if ! sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli plugins install @openclaw/slack 2>&1; then
  echo "Plugin install reported an error; checking if @openclaw/slack is already present..."
  sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
    run --rm openclaw-cli plugins list 2>&1 | grep -i slack || {
      echo "Slack plugin not installed; re-run with: plugins install @openclaw/slack --force" >&2
      exit 1
    }
  echo "Slack plugin already installed; continuing."
fi
REMOTE

if [[ "$PREP_ONLY" == "true" ]]; then
  echo "Prep complete. Create Slack app (SLACK_APP_SETUP.md), export tokens + GEMINI_API_KEY, re-run without --prep-only."
  exit 0
fi

echo "==> Apply Slack socket config patch"
vm_config_patch "$SOCKET_PATCH_IN_CONTAINER"

echo "==> Apply channel policy patch (sandbox groupPolicy open)"
vm_config_patch "$POLICY_PATCH_IN_CONTAINER"

# Do not run `openclaw models set` here — it drifts primary to 3.5-flash (20 RPD) and
# fights the 3.1 stack. Apply model-failover patch for allowlist/baseUrl hints only;
# full primary + provider registry: ./vm/setup-model-stack.sh (required next step).
echo "==> Apply model failover patch (partial; run setup-model-stack.sh next)"
vm_config_patch "$MODEL_PATCH_IN_CONTAINER"

echo "==> Restart gateway"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  up -d --no-build --force-recreate
sleep 12
curl -sS -i http://127.0.0.1:18789/healthz | head -20
REMOTE

echo "==> models status (auth check)"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli models status 2>&1 | head -40 || true
REMOTE

echo "==> Gateway log checks (socket + agent model)"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
LOGS=$(sudo docker logs openclaw-openclaw-gateway-1 2>&1 | grep -iE 'socket mode connected|agent model' | tail -5)
if [[ -z "$LOGS" ]]; then
  echo "WARN: expected 'socket mode connected' and/or 'agent model' not found in recent logs" >&2
  sudo docker logs openclaw-openclaw-gateway-1 2>&1 | tail -30
  exit 1
fi
echo "$LOGS"
REMOTE

cat <<EOF

Done. Required next (model stack — do not skip):
  ./vm/setup-google-genai-proxy.sh
  ./vm/setup-model-stack.sh

Optional:
  ./vm/setup-persona.sh (see docs/PERSONAL_AGENT.md)

Then Slack: @OpenClaw hello in an invited channel (new thread; prefer @mention).
If no reply: docs/TROUBLESHOOTING.md § Slack-only setup drifted model stack.

EOF
