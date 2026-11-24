# Gemini models — CS506 sandbox (`REDACTED-gcp-project`)

Free-tier limits: [AI Studio rate limits (28 days)](https://aistudio.google.com/rate-limit?timeRange=last-28-days). **RPD** resets midnight Pacific. Limits are **per project**, but **each model id has its own RPD bucket** on Free tier — failover can use **~60 requests/day** across three 20-RPD chat models when one bucket is exhausted.

**Runtime stack:** [`gcp/vm/model-failover.patch.json5`](../gcp/vm/model-failover.patch.json5) + [`gcp/vm/google-provider-models.replace.json5`](../gcp/vm/google-provider-models.replace.json5) — apply via [`gcp/vm/setup-model-stack.sh`](../gcp/vm/setup-model-stack.sh) (preceded by [`gcp/vm/setup-google-genai-proxy.sh`](../gcp/vm/setup-google-genai-proxy.sh), see below).

| Role | OpenClaw id | AI Studio RPD (typical Free) | Notes |
|------|-------------|------------------------------|--------|
| **Primary** | `google/gemini-3.1-flash-lite` | **500** | Unblocked via URL-rewrite proxy (2026-05-26). See [`docs/MODEL_RECOVERY_PLAN.md`](./MODEL_RECOVERY_PLAN.md). |
| **Fallback 1** | `google/gemini-3.5-flash` | 20 | Standard provider registry path. |
| **Removed (over RPD 2026-05-26)** | `google/gemini-2.5-flash-lite` | 20 | Re-add after Pacific midnight reset. |
| **Removed (over RPD 2026-05-26)** | `google/gemini-2.5-flash` | 20 | Re-add after Pacific midnight reset. |

### Why 3.1 needs the proxy

OpenClaw 2026.5.19 contains a baked-in alias map that rewrites `google/gemini-3.1-flash-lite` → `google/gemini-3.1-flash-lite-preview` **inside the gateway runtime**. The `-preview` model was retired by Google → 404 NOT_FOUND. Config-layer overrides do not bypass it (verified). The proxy ([`gcp/vm/google-genai-proxy.py`](../gcp/vm/google-genai-proxy.py)) intercepts the outbound URL and un-rewrites it before forwarding to Google. It also patches a secondary OpenClaw bug where streaming requests are issued without the required `/v1beta/` prefix. Full root cause + workaround in [`docs/MODEL_RECOVERY_PLAN.md`](./MODEL_RECOVERY_PLAN.md).

Upstream: [Gemini API rate limits](https://ai.google.dev/gemini-api/docs/rate-limits). OpenClaw failover: [model failover](https://docs.openclaw.ai/concepts/model-failover). Fixes: [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md).

### Why provider registry matters

OpenClaw requires **both**:

1. `agents.defaults.models["google/gemini-3.5-flash"]` (allowlist), and  
2. `models.providers.google.models[]` with `{ id: "gemini-3.5-flash" }`.

Without (2), Slack shows **`model not found`** even when curl to Gemini returns **200**.

Set `models.providers.google.api` to **`"google-generative-ai"`**. If 3.5 is routed via `openai-responses`, you may see **401 Incorrect API key** (wrong API surface for `GEMINI_API_KEY`).

### Fallback behavior (OpenClaw)

| Behavior | What happens |
|----------|----------------|
| **Each run** | Start on **primary** (`3.5-flash`). On 429 / model / auth errors, try **fallbacks in order**. |
| **Sticky fallback** | Successful fallback may stick for the **session** until primary probe succeeds (~5 min). |
| **Shared project** | All models use the same `GEMINI_API_KEY`; **separate model RPD buckets** still help when only one model is exhausted. |
| **Notices** | Slack: `↪️ Model Fallback: …` once per state change. |

---

## Text-chat smoke matrix (2026-05-26)

API smoke: [`gcp/vm/smoke-gemini-chat-models.sh`](../gcp/vm/smoke-gemini-chat-models.sh).  
OpenClaw smoke: [`gcp/vm/smoke-openclaw-models.sh`](../gcp/vm/smoke-openclaw-models.sh).

| API model | HTTP | RPD (Free) | OpenClaw (2026-05-26 evening) |
|-----------|------|------------|------------------------|
| `gemini-3.1-flash-lite` | **200** | **9/500** | **OK via proxy** — primary |
| `gemini-3.5-flash` | 429 (RPM peg) | 10/20 | Fallback; standard provider registry path |
| `gemini-2.5-flash-lite` | **429** | 29/20 (over) | Removed from stack until RPD reset |
| `gemini-2.5-flash` | **429** | 25/20 (over) | Removed from stack until RPD reset |
| `gemini-3.1-flash-lite-preview` | 404 | — | Retired (the wrong id OpenClaw resolves to; intercepted by proxy) |

Re-run API smoke when quotas reset; re-run OpenClaw smoke after config changes.

---

## Operator commands

**Apply model stack** (no Slack token changes):

```bash
cd experiments/openclaw-google/gcp
./scripts/start-vm.sh
./vm/setup-google-genai-proxy.sh   # Docker sidecar; un-rewrites the 3.1 url
./vm/setup-model-stack.sh          # config patch + restart
./scripts/vm-exec.sh bash -s < vm/smoke-openclaw-models.sh
```

**Golden setup** (Slack + model stack):

```bash
export SLACK_APP_TOKEN='...' SLACK_BOT_TOKEN='...' GEMINI_API_KEY='...'
./vm/setup-slack-socket.sh
```

**Verify Slack:**

```bash
./scripts/vm-exec.sh -- timeout 15 sudo docker logs --since 10m --tail 40 openclaw-openclaw-gateway-1 2>&1 \
  | grep -iE 'agent model|429|404|Unknown|Model Fallback'
```

**Check config:**

```bash
./scripts/vm-exec.sh bash -s 'sudo docker compose -f $HOME/openclaw/docker-compose.yml --project-directory $HOME/openclaw run --rm openclaw-cli models status 2>&1 | head -16'
```

---

## Future tasks

- **OpenClaw image bump:** when upstream fixes the `gemini-3.1-flash-lite -> -preview` alias, delete the proxy sidecar and drop `models.providers.google.baseUrl` from the patch files.
- **Pacific RPD reset:** re-add `gemini-2.5-flash-lite` and `gemini-2.5-flash` as additional fallbacks once both are back under 20/20.
- **Billing / tier:** if even 3.1's 500 RPD is insufficient at class scale, raise AI Studio tier (project-wide).
