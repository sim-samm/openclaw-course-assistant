#!/usr/bin/env bash
# Deploy Stage 3 persona workspace files to the OpenClaw VM (no Slack tokens required).
# Copies IDENTITY.md, USER.md, SOUL.md, AGENTS.md, TOOLS.md from gcp/vm/workspace/ to ~/.openclaw/workspace/
# and restarts the gateway so boot-md picks them up on the next session.
#
# Usage (from experiments/openclaw-google/gcp):
#   ./scripts/start-vm.sh          # if VM is stopped
#   ./vm/setup-persona.sh
#   ./vm/setup-persona.sh --no-restart
#
# After deploy: verify with @OpenClaw in Slack (see docs/PERSONAL_AGENT.md demo pack).
set -euo pipefail

NO_RESTART=false
if [[ "${1:-}" == "--no-restart" ]]; then
  NO_RESTART=true
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GCP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
WORKSPACE_SRC="$SCRIPT_DIR/workspace"
# shellcheck source=../scripts/lib.sh
source "$GCP_DIR/scripts/lib.sh"
load_phase0_env

VM_EXEC="$GCP_DIR/scripts/vm-exec.sh"

if [[ ! -x "$VM_EXEC" ]]; then
  echo "Missing vm-exec: $VM_EXEC" >&2
  exit 1
fi

for f in IDENTITY.md USER.md SOUL.md AGENTS.md TOOLS.md; do
  if [[ ! -f "$WORKSPACE_SRC/$f" ]]; then
    echo "Missing workspace file: $WORKSPACE_SRC/$f" >&2
    exit 1
  fi
done

vm_copy_workspace_file() {
  local name=$1
  local local_file="$WORKSPACE_SRC/$name"
  local content_b64
  content_b64=$(base64 < "$local_file" | tr -d '\n')
  "$VM_EXEC" bash -s "$name" "$content_b64" <<'REMOTE'
set -euo pipefail
NAME=$1
CONTENT_B64=$2
WS="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
mkdir -p "$WS"
CONTENT=$(printf '%s' "$CONTENT_B64" | base64 -d)
DEST="$WS/$NAME"
if [[ -f "$DEST" ]]; then
  cp -a "$DEST" "$DEST.bak.$(date -u +%Y%m%dT%H%M%SZ)"
fi
printf '%s' "$CONTENT" > "$DEST"
chmod 600 "$DEST"
echo "Wrote $DEST ($(wc -c < "$DEST") bytes)"
REMOTE
}

echo "==> Deploy persona workspace files to VM (~/.openclaw/workspace)"
for f in IDENTITY.md USER.md SOUL.md AGENTS.md TOOLS.md; do
  vm_copy_workspace_file "$f"
done

echo "==> Retire BOOTSTRAP.md (prevents generic 'Who am I?' first-run ritual)"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
WS="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
BOOT="$WS/BOOTSTRAP.md"
if [[ -f "$BOOT" ]]; then
  mv "$BOOT" "$WS/BOOTSTRAP.md.retired.$(date -u +%Y%m%dT%H%M%SZ)"
  echo "Retired $BOOT"
else
  echo "No BOOTSTRAP.md present (already retired)"
fi
REMOTE

echo "==> List workspace on VM"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
WS="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
ls -la "$WS"/*.md 2>/dev/null || ls -la "$WS"
REMOTE

if [[ "$NO_RESTART" == "true" ]]; then
  echo "Skipping gateway restart (--no-restart). New sessions pick up files on next natural restart."
  exit 0
fi

echo "==> Restart gateway (persona loaded via boot-md on new sessions)"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  up -d --no-build --force-recreate
sleep 12
curl -sS -i http://127.0.0.1:18789/healthz | head -15
REMOTE

cat <<'EOF'

Done (Stage 3 persona files on VM).

Next steps:
  1. In Slack: @OpenClaw in a **new thread** — expect Clawde intro, not "Who am I?"
  2. Run demo prompts D1–D6: docs/PERSONAL_AGENT.md
  3. Record pass/fail in journal.md § Product milestones (persona: clawde-v1)

EOF
