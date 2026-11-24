#!/usr/bin/env bash
# Deploy the Google Generative AI URL-rewrite proxy as a Docker sidecar on the
# openclaw_default network. Workaround for OpenClaw 2026.5.19 normalization bug
# (google/gemini-3.1-flash-lite -> google/gemini-3.1-flash-lite-preview -> 404).
#
# Idempotent: removes and recreates the container if it already exists.
# Tests rewrite end-to-end against Google before returning success.
#
# Usage (from experiments/openclaw-google/gcp):
#   ./scripts/start-vm.sh
#   ./vm/setup-google-genai-proxy.sh
#
# After this runs, point OpenClaw at the proxy with:
#   models.providers.google.baseUrl: "http://google-genai-proxy:8788"
# Either via setup-model-stack.sh or model-failover.patch.json5.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GCP_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
# shellcheck source=../scripts/lib.sh
source "$GCP_DIR/scripts/lib.sh"
load_phase0_env

VM_EXEC="$GCP_DIR/scripts/vm-exec.sh"
PROXY_LOCAL="$SCRIPT_DIR/google-genai-proxy.py"
PROXY_NAME="google-genai-proxy.py"
CONTAINER_NAME="google-genai-proxy"
NETWORK_NAME="openclaw_default"
LISTEN_PORT="8788"
PYTHON_IMAGE="python:3.11-slim"

if [[ ! -x "$VM_EXEC" || ! -f "$PROXY_LOCAL" ]]; then
  echo "Missing vm-exec or $PROXY_LOCAL" >&2
  exit 1
fi

echo "==> Copy proxy script to VM"
PROXY_B64=$(base64 < "$PROXY_LOCAL" | tr -d '\n')
"$VM_EXEC" bash -s "$PROXY_NAME" "$PROXY_B64" <<'REMOTE'
set -euo pipefail
PROXY_NAME=$1
PROXY_B64=$2
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"
mkdir -p "$ROOT"
printf '%s' "$PROXY_B64" | base64 -d > "$ROOT/$PROXY_NAME"
chmod 644 "$ROOT/$PROXY_NAME"
REMOTE

echo "==> (Re)create proxy container on $NETWORK_NAME"
"$VM_EXEC" bash -s "$CONTAINER_NAME" "$NETWORK_NAME" "$LISTEN_PORT" "$PYTHON_IMAGE" "$PROXY_NAME" <<'REMOTE'
set -euo pipefail
NAME=$1
NET=$2
PORT=$3
IMAGE=$4
PROXY_NAME=$5
ROOT="${OPENCLAW_HOME:-$HOME/openclaw}"

sudo docker rm -f "$NAME" >/dev/null 2>&1 || true
if ! sudo docker network inspect "$NET" >/dev/null 2>&1; then
  echo "Network $NET not found; is the gateway running?" >&2
  exit 1
fi
sudo docker run -d \
  --name "$NAME" \
  --network "$NET" \
  --restart unless-stopped \
  -v "$ROOT/$PROXY_NAME:/proxy.py:ro" \
  "$IMAGE" \
  python /proxy.py "$PORT" >/dev/null
sleep 2
sudo docker ps --filter "name=$NAME" --format 'table {{.Names}}\t{{.Status}}\t{{.Networks}}'
REMOTE

echo "==> Smoke: rewrite '-preview' -> stable -> Google (from gateway container)"
"$VM_EXEC" bash -s <<'REMOTE'
set -euo pipefail
ENV_FILE="${OPENCLAW_HOME:-$HOME/openclaw}/.env"
set -a
# shellcheck source=/dev/null
source "$ENV_FILE" 2>/dev/null || true
set +a
KEY="${GEMINI_API_KEY:-}"
if [[ -z "$KEY" ]]; then
  echo "GEMINI_API_KEY missing in $ENV_FILE" >&2
  exit 1
fi
# Use a throwaway container on the same network to test resolution + rewrite.
sudo docker run --rm --network openclaw_default curlimages/curl:8.10.1 \
  -sS -o /tmp/r.json -w "preview->stable HTTP=%{http_code}\n" --max-time 25 \
  "http://google-genai-proxy:8788/v1beta/models/gemini-3.1-flash-lite-preview:generateContent?key=${KEY}" \
  -H "Content-Type: application/json" \
  -d '{"contents":[{"parts":[{"text":"OK"}]}],"generationConfig":{"maxOutputTokens":4}}'
REMOTE

cat <<EOF

Proxy live at http://${CONTAINER_NAME}:${LISTEN_PORT} on docker network ${NETWORK_NAME}.
Next: ensure models.providers.google.baseUrl in ~/.openclaw/openclaw.json points
at the proxy (./vm/setup-model-stack.sh applies this), then restart gateway.
Logs: ./scripts/vm-exec.sh sudo docker logs -f ${CONTAINER_NAME}

EOF
