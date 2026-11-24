# Troubleshooting — openclaw-google

Day-to-day operator fixes for the **personal agent via Slack** on GCE. Product context: [`PRODUCT.md`](../PRODUCT.md).

**Historical narrative:** [`archive/MANIFEST.md`](../archive/MANIFEST.md) (`post-mortems/` in tarball).

**Working directory:** `experiments/openclaw-google/gcp/`

---

## Quick checks

Run with VM **RUNNING** (`./scripts/start-vm.sh` if needed).

| Check | Command | Expected |
|-------|---------|----------|
| VM up | `./scripts/describe-vm.sh` | **RUNNING** |
| Recent errors (bounded) | `./scripts/vm-exec.sh -- timeout 15 sudo docker logs --since 2h --tail 40 openclaw-openclaw-gateway-1` | No `429` / `Embedded agent failed before reply` after a test mention |
| Gateway health | `./scripts/vm-exec.sh curl -sS http://127.0.0.1:18789/healthz` | HTTP 200, `"status":"live"` |
| Slack socket | `./scripts/vm-exec.sh bash -s 'sudo docker logs openclaw-openclaw-gateway-1 2>&1 \| grep -i "socket mode connected" \| tail -1'` | `[slack] socket mode connected` |
| Model | `./scripts/vm-exec.sh bash -s 'ROOT=$HOME/openclaw; sudo docker compose -f $ROOT/docker-compose.yml --project-directory $ROOT run --rm openclaw-cli models status 2>&1 \| head -20'` | Primary `google/gemini-3.1-flash-lite-preview` (CLI **read-time normalization** of stable id — see [`MODEL_RECOVERY_PLAN.md`](./MODEL_RECOVERY_PLAN.md)), fallback `gemini-3.5-flash`; auth OK |
| Agent model in logs | `./scripts/vm-exec.sh bash -s 'sudo docker logs openclaw-openclaw-gateway-1 2>&1 \| grep -i "agent model" \| tail -1'` | `agent model: google/gemini-3.1-flash-lite-preview` (same normalization; proxy un-rewrites at network) |
| Proxy sidecar | `./scripts/vm-exec.sh sudo docker logs --tail 5 google-genai-proxy` | Last line shows `rewrite … notes=gemini-3.1-flash-lite-preview->gemini-3.1-flash-lite` and a `HTTP/1.1" 200` |

If healthz fails, fix **Runtime** (Stage 1) before Slack. If socket is connected but `@mention` is silent, fix **Model** or channel policy below.

---

## Symptom → cause → fix

| Symptom | Often mistaken for | Likely cause | Fix |
|---------|-------------------|--------------|-----|
| No reply to `@mention` | Bad Slack tokens | Channel **`groupPolicy: allowlist`** with no channel IDs, or missing `channels.slack` config | Re-run [`../gcp/vm/setup-slack-socket.sh`](../gcp/vm/setup-slack-socket.sh) (applies policy + socket patch) |
| Thinking/typing in Slack, **no final reply** | Slack broken | **429** (quota), **404** (retired preview), **Unknown model** (missing `models.providers.google.models[]`), or **401** on 3.5 (wrong `api` — needs `google-generative-ai`) | Re-run [`../gcp/vm/setup-model-stack.sh`](../gcp/vm/setup-model-stack.sh); [`GEMINI_RATE_LIMITS.md`](./GEMINI_RATE_LIMITS.md) |
| `/openclaw` did not respond | Slack app broken | Wrong default model or **no API key** for that provider | Set `GEMINI_API_KEY` on VM; re-run [`../gcp/vm/setup-model-stack.sh`](../gcp/vm/setup-model-stack.sh) (writes primary directly via patch — do **not** use `openclaw models set` for the 3.1 primary, it triggers the normalization bug) |
| `socket mode connected` but no chat | Slack scopes | Channel policy or model auth — **not** transport | See policy + model rows above |
| Bot never replies anywhere | Slack wiring | No LLM auth on VM | Export `GEMINI_API_KEY`; re-run setup script |
| `SecretRefResolutionError` for `SLACK_*` | Patch file wrong | Tokens not in VM `~/openclaw/.env` | Re-run setup script with `SLACK_APP_TOKEN` + `SLACK_BOT_TOKEN` exported |
| `/healthz` connection refused | VM broken | Gateway crash loop — often missing **`gateway.mode`** | See [Gateway crash loop](#gateway-crash-loop-stage-1) |
| Setup “failed” with VM stopped | Slack manifest | VM off only blocks VM steps; Slack app creation is browser-only | `./scripts/start-vm.sh`, then re-run setup |
| Bot silent in DM | Broken bot | **Pairing** not approved | Upstream pairing; Control UI via `./scripts/ssh-tunnel.sh` |
| `plugin already exists` then nothing works | Need reinstall | Old script exited before patch/restart | Re-run current setup script (continues on existing plugin) |
| `invalid_auth` in logs | Network | Revoked or wrong Slack token | Regenerate in Slack app settings; update VM `.env`; restart |
| Plugin requires OpenClaw ≥ 2026.5.12 | Slack bug | Old image | Update `OPENCLAW_IMAGE` digest in VM `.env`; recreate compose |

**Demo tip:** Prefer **`@mention`** over `/openclaw` — slash commands time out more easily under slow model latency.

### Slack-only setup drifted model stack (2026-05-30)

**Symptom:** `@mention` worked right after a Slack token change, then **stopped replying the next day** (or showed typing with no message). **`socket mode connected`** in logs; Slack transport looked fine.

**Root cause (confirmed):** Operator ran **only** [`../gcp/vm/setup-slack-socket.sh`](../gcp/vm/setup-slack-socket.sh) when moving the bot to a new workspace (`pdx-cs`). That script **reset the runtime model** to **`google/gemini-3.5-flash`** via `openclaw models set` and did **not** re-apply the full stack from [`../gcp/vm/setup-model-stack.sh`](../gcp/vm/setup-model-stack.sh).

Result on the VM:

| Config | Drifted state | Intended state |
|--------|---------------|----------------|
| Primary | `google/gemini-3.5-flash` (20 RPD) | `google/gemini-3.1-flash-lite` via proxy (500 RPD) |
| Fallback | `3.5-flash` → `3.5-flash` (no real failover) | `3.5-flash` as secondary only |
| Provider registry | Incomplete | `google-provider-models.replace.json5` applied |

**Why it failed overnight:** Free-tier **RPD on `gemini-3.5-flash` exhausted** (~20/day shared). With primary and fallback both on 3.5, OpenClaw had **no alternate model bucket**. Slack stayed connected; the **model layer** failed silently or with 429 in gateway logs.

**Not the cause:** Reusing a previously deployed VM, skipping `setup-persona.sh`, or new Slack tokens alone.

**Fix (verified 2026-05-30):**

```bash
cd experiments/openclaw-google/gcp
./scripts/start-vm.sh   # if needed
./vm/setup-google-genai-proxy.sh   # idempotent; ensures proxy sidecar
./vm/setup-model-stack.sh          # restores primary + fallback + provider registry
```

Then Slack smoke: **new thread** → `@OpenClaw hi`. Expect reply (confirmed in `#cs112` / `pdx-cs`).

**Prevention:** After **every** `setup-slack-socket.sh` (new tokens, workspace move, reinstall), **always** run `setup-model-stack.sh`. See [Golden recovery](#golden-recovery-recommended) below.

**Script noise (benign):** `Alias not found: gemini-flash-lite` during stack setup — alias already removed. `curl: (52) Empty reply` right after recreate — gateway still starting; retry `healthz` after ~30s or re-run with longer wait.

---

### “Something went wrong” + `/new`

| Cause | What you see | Fix |
|-------|----------------|-----|
| **All models 429** | Retries on primary only; then generic error | Check [AI Studio rate limits](https://aistudio.google.com/rate-limit); wait for Pacific reset; API smoke in [`GEMINI_RATE_LIMITS.md`](./GEMINI_RATE_LIMITS.md) |
| **Stale session** | `EmbeddedAttemptSessionTakeoverError` in logs | In Slack: `/new` then `@OpenClaw` again in a **new thread** |
| **Stale `3.1-preview` alias** | `Aliases: gemini-flash-lite -> …-preview` in `models status` | Cosmetic only in 2026.5.19 (baked-in alias map). Proxy un-rewrites at network. See [`MODEL_RECOVERY_PLAN.md`](./MODEL_RECOVERY_PLAN.md). |
| **Proxy sidecar down** | Gateway logs: `getaddrinfo ENOTFOUND google-genai-proxy` or `ECONNREFUSED :8788` | Re-run [`../gcp/vm/setup-google-genai-proxy.sh`](../gcp/vm/setup-google-genai-proxy.sh). |

The alias is **not** usually the direct cause of a single failed turn; it is **stale config** that can confuse failover if something routes to `gemini-flash-lite`.

---

## Golden recovery (recommended)

One idempotent path from `gcp/`:

```bash
./scripts/start-vm.sh   # if TERMINATED

export SLACK_APP_TOKEN='xapp-...'
export SLACK_BOT_TOKEN='xoxb-...'
export GEMINI_API_KEY='...'    # optional unless rotating key

./vm/setup-slack-socket.sh
./vm/setup-google-genai-proxy.sh   # idempotent
./vm/setup-model-stack.sh          # required — do not skip after Slack setup
```

`setup-slack-socket.sh`: tokens → Slack plugin → socket + channel policy → gateway restart.

`setup-model-stack.sh`: primary **`gemini-3.1-flash-lite`** (500 RPD via proxy) + **`gemini-3.5-flash`** fallback + provider registry. **Skipping this step drifts the VM to 3.5-only and causes next-day silence when 3.5 RPD is exhausted** — see [Slack-only setup drift](#slack-only-setup-drifted-model-stack-2026-05-30).

Then in Slack: `@OpenClaw hello` in an invited channel (new thread recommended).

---

## URL-rewrite proxy (`google-genai-proxy`)

Workaround for the OpenClaw 2026.5.19 baked-in alias map that maps `google/gemini-3.1-flash-lite` → `…-preview` (retired → 404). Full root cause in [`MODEL_RECOVERY_PLAN.md`](./MODEL_RECOVERY_PLAN.md).

### Operational notes

| Topic | Detail |
|-------|--------|
| **Health probe** | `./scripts/vm-exec.sh sudo docker logs --tail 5 google-genai-proxy` — expect `rewrite … notes=gemini-3.1-flash-lite-preview->gemini-3.1-flash-lite[,prefix-v1beta]` then `HTTP/1.1" 200`. No bound health endpoint. |
| **Degraded mode** | If the proxy is down, gateway logs `getaddrinfo ENOTFOUND google-genai-proxy` (or `ECONNREFUSED`), 3.1 returns 404, and **all traffic falls over to `gemini-3.5-flash` (20 RPD)**. Quota burns ~25× faster — you will exhaust the 3.5 bucket in minutes during class. Re-deploy with [`../gcp/vm/setup-google-genai-proxy.sh`](../gcp/vm/setup-google-genai-proxy.sh). |
| **Streaming timeout** | `urlopen(..., timeout=120)` in [`../gcp/vm/google-genai-proxy.py`](../gcp/vm/google-genai-proxy.py). Long D-prompt SSE streams can truncate — bump if you see partial replies. |
| **Maintenance scope** | Rewrites are in `REWRITES = [...]` (top of `google-genai-proxy.py`). Upstream host is `UPSTREAM_HOST` one line above. New retired aliases (e.g. future `…-preview`) need entries here. |
| **Sunset condition** | When OpenClaw upstream fixes the alias and `agent --local` on the next image bump returns `OK` against `google/gemini-3.1-flash-lite` **without** a proxy in front, delete the sidecar (`docker rm -f google-genai-proxy`) and drop `models.providers.google.baseUrl` from [`model-failover.patch.json5`](../gcp/vm/model-failover.patch.json5) + [`google-provider-models.replace.json5`](../gcp/vm/google-provider-models.replace.json5). |
| **Security** | Gateway → proxy is **plain HTTP on the docker bridge**. `GEMINI_API_KEY` rides in the URL query string. Acceptable for the single-VM class demo; **do not** reuse this pattern on shared/multi-tenant infra without TLS + an auth header. |
| **Network coupling** | Proxy lives on docker network `openclaw_default`. If the compose project name changes, the network name changes, and the gateway can no longer resolve `google-genai-proxy` — update `setup-google-genai-proxy.sh` (`NETWORK_NAME`) and the `baseUrl` host. |
| **Single point of failure** | One proxy serves all class traffic. For an N-student demo, monitor with `docker logs -f google-genai-proxy`; have the redeploy script ready. |

---

## Gateway crash loop (Stage 1)

Symptoms: `/healthz` refused; container **Restarting (exit 78)**; logs mention missing **`gateway.mode`**.

| Cause | Fix |
|-------|-----|
| Removed `--allow-unconfigured` before `gateway.mode` set | Re-patch bootstrap if needed; run [`../gcp/vm/onboard-noninteractive-local.sh`](../gcp/vm/onboard-noninteractive-local.sh); remove bootstrap flag per [`../gcp/README.md`](../gcp/README.md) **Harden** |
| `openclaw setup --non-interactive` without `--accept-risk` | Use documented flags in onboard script |
| Relative compose path under `sudo` | Use absolute paths: `$HOME/openclaw/docker-compose.yml` |

Historical bootstrap narrative: [`archive/MANIFEST.md`](../archive/MANIFEST.md) (`post-mortems/phase-0-openclaw-gcp-post-mortem.md` in tarball).

---

## Manual patch (if script wrote tokens but failed mid-run)

```bash
./scripts/vm-exec.sh bash -s <<'EOF'
ROOT="$HOME/openclaw"
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli config patch --file /home/node/.openclaw/slack.socket.patch.json5
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli config patch --file /home/node/.openclaw/slack-channel-policy.patch.json5
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  run --rm openclaw-cli config patch --file /home/node/.openclaw/model-failover.patch.json5
sudo docker compose -f "$ROOT/docker-compose.yml" --project-directory "$ROOT" \
  up -d --no-build --force-recreate
sleep 15
curl -sS http://127.0.0.1:18789/healthz
EOF
```

> Do **not** include `openclaw-cli models set google/gemini-3.1-flash-lite` here — that command applies the 2026.5.19 baked-in alias and rewrites the primary back to `…-preview`. The patch sets `agents.defaults.model.primary` directly, which is what the gateway reads.

---

## Bot will not read course PDFs

**Symptom:** `@OpenClaw` answers syllabus or slide questions from general knowledge, or says it cannot read files.

| Check | Command / action | Expected |
|-------|------------------|----------|
| PDFs on VM | `./scripts/vm-exec.sh ls -la ~/.openclaw/workspace/course/` | Nine `cs112-*.pdf` files |
| Tools patch applied | Re-run [`../gcp/vm/setup-course-materials.sh`](../gcp/vm/setup-course-materials.sh) or `--patch-only` | `course-tools.patch.json5` merged |
| Sandbox blocking tools | On VM via compose: `openclaw-cli sandbox explain` | `read` and `pdf` allowed for Slack session |
| Path in prompt | Student names `course/cs112-01-models-prompts.pdf` (not laptop path) | Agent uses `pdf` tool |
| Page/size limits | [`course-tools.patch.json5`](../gcp/vm/course-tools.patch.json5): `pdfMaxPages: 70`, `pdfMaxBytesMb: 10` | Decks under 10 MB; long decks may truncate — bot should say so |

**Fix:** From `gcp/`: `./vm/setup-course-materials.sh` then `./vm/setup-persona.sh`. Regenerate local PDFs: `cd vm/course-materials && ./prep-pdfs-for-openclaw.sh`.

---

## Security reminders

- Tokens and API keys only in VM `~/openclaw/.env` (mode **600**), never in git or `journal.md` values.
- Record Slack app **name/ID** and env var **names** only in journal.
- Do not expose gateway `:18789` publicly without [Gateway security](https://docs.openclaw.ai/gateway/security).

---

## When to read other docs

| Need | Document |
|------|----------|
| First-time Slack app creation | [`SLACK_APP_WALKTHROUGH.md`](./SLACK_APP_WALKTHROUGH.md) |
| Full incident timeline / war stories | Post-mortems (links at top) |
| Live demo script | [`PHASE1_DEMO.md`](./PHASE1_DEMO.md), [`../DEMO.md`](../DEMO.md) |
| Ops phases and hardening | [`../RUNBOOK.md`](../RUNBOOK.md) |
| Upstream OpenClaw behavior | [`openclaw-docs-index.md`](./openclaw-docs-index.md) |
| Gemini Free-tier limits / model choice | [`GEMINI_RATE_LIMITS.md`](./GEMINI_RATE_LIMITS.md) |
