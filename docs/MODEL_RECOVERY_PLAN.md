# Model recovery plan — Slack bot not replying

**Symptom:** Slack shows *“Something went wrong…”* or no reply; gateway may log **429**, **404 preview**, or **EmbeddedAttemptSessionTakeoverError**.

**Goal:** Pick models with **RPD headroom today**, wire them in OpenClaw (registry + `google-generative-ai`), verify Slack `@mention` → reply.

Related: [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md), [`GEMINI_RATE_LIMITS.md`](./GEMINI_RATE_LIMITS.md), [`gcp/vm/setup-model-stack.sh`](../gcp/vm/setup-model-stack.sh).

---

## Live quota snapshot (operator — 2026-05-26)

From [AI Studio rate limits](https://aistudio.google.com/rate-limit?timeRange=last-28-days) (project `REDACTED-gcp-project`):

| Model | RPD used / limit | RPM | Verdict for **today** |
|-------|------------------|-----|------------------------|
| **Gemini 3.1 Flash Lite** | **9 / 500** | 2 / 15 | **Best primary** — most headroom |
| Gemini 3.5 Flash | 10 / 20 | 5 / 5 (maxed) | OK as **fallback** only |
| Gemini 2.5 Flash Lite | **29 / 20** | 3 / 10 | **Over RPD** — do not use until reset |
| Gemini 2.5 Flash | **25 / 20** | 3 / 5 | **Over RPD** — do not use until reset |
| Gemini 2.5 Pro, 2 Flash*, 3 Pro, 3 Flash | 0 / 0 | — | Not enabled on Free |

**Conclusion:** Current stack (`3.5` → `2.5-lite` → `2.5`) targets **exhausted** buckets. AI Studio shows **3.1 Flash Lite** usage (9 RPD) — API works; OpenClaw must call **`gemini-3.1-flash-lite`** (stable), not **`…-preview`** (404).

---

## Known failure modes (already observed)

| Mode | Evidence | Fix direction |
|------|----------|----------------|
| **Wrong API surface** | `openai-responses` + **401** on 3.5 | `models.providers.google.api: "google-generative-ai"` |
| **Missing registry** | `model not found` for 3.5 | `models.providers.google.models[]` + allowlist |
| **Preview alias** | `gemini-flash-lite` → `3.1-flash-lite-preview` | Remove alias; delete preview from allowlist ([`model-cleanup-preview.patch.json5`](../gcp/vm/model-cleanup-preview.patch.json5)) |
| **429 on primary, no failover** | Logs: repeated `gemini-3.5-flash` 429, then session error | Reorder stack; confirm fallbacks in **gateway** logs show `model-fallback` |
| **Stale Slack session** | `EmbeddedAttemptSessionTakeoverError` | User: **`/new`**, new thread |

---

## Recovery plan (ordered)

### Phase A — Diagnose (15 min, on VM)

From `experiments/openclaw-google/gcp/`:

```bash
./scripts/start-vm.sh
./scripts/vm-exec.sh curl -sS http://127.0.0.1:18789/healthz
./scripts/vm-exec.sh bash -s < vm/smoke-gemini-chat-models.sh
./scripts/vm-exec.sh bash -s < vm/smoke-openclaw-models.sh
./scripts/vm-exec.sh bash -s 'sudo docker compose -f $HOME/openclaw/docker-compose.yml --project-directory $HOME/openclaw run --rm openclaw-cli models status 2>&1 | head -20'
```

Record per model: **API HTTP**, **OpenClaw probe** (`OK` / `429` / `404` / `model_not_found`).

**Pass criteria for Phase B:** Know which OpenClaw ids return **OK** on agent probe (not just `models set`).

### Phase B — Fix 3.1 Flash Lite in OpenClaw (30–60 min) — **priority**

**Target stack (quota-driven):**

| Role | OpenClaw id | API id |
|------|-------------|--------|
| **Primary** | `google/gemini-3.1-flash-lite` | `gemini-3.1-flash-lite` |
| **Fallback 1** | `google/gemini-3.5-flash` | `gemini-3.5-flash` |
| ~~Fallback 2~~ | ~~2.5-*~~ | Omit until RPD &lt; 20 |

**Spike steps (try in order until agent probe returns OK):**

1. Provider registry + api (existing pattern in [`google-provider-models.replace.json5`](../gcp/vm/google-provider-models.replace.json5)):
   - Add `{ id: "gemini-3.1-flash-lite", name: "Gemini 3.1 Flash Lite" }`
   - Keep `api: "google-generative-ai"`
2. Allowlist: `"google/gemini-3.1-flash-lite": {}` — **not** `…-preview`
3. `openclaw models set google/gemini-3.1-flash-lite` → confirm **Default model** line does **not** say `…-preview`
4. If still preview: `openclaw models aliases list` — remove any `gemini-flash-lite` → preview
5. If still preview: try `agents.defaults.models["google/gemini-3.1-flash-lite"].params` with explicit model id (per upstream Google provider docs)
6. `openclaw doctor --fix` (non-interactive on VM) — record what changed
7. Agent probe: `openclaw agent --local --session-id recovery-31 --message "Reply OK"`

Update [`model-failover.patch.json5`](../gcp/vm/model-failover.patch.json5) + [`google-provider-models.replace.json5`](../gcp/vm/google-provider-models.replace.json5), then:

```bash
./vm/setup-model-stack.sh
```

### Phase C — Gateway + Slack verify (10 min)

```bash
./scripts/vm-exec.sh bash -s 'sudo docker logs --since 5m openclaw-openclaw-gateway-1 2>&1 | grep -iE "agent model|429|404|fallback|Embedded" | tail -20'
```

**Slack (operator):**

1. `/new`
2. New thread → `@OpenClaw hi`
3. Expect Clawde reply (no generic error)

### Phase D — Document + journal

- Update [`GEMINI_RATE_LIMITS.md`](./GEMINI_RATE_LIMITS.md) with live RPD table and chosen stack
- `journal.md` § Model recovery — date, stack, smoke results (no secrets)

---

## Success criteria

- [ ] `smoke-openclaw-models.sh`: **primary (3.1-flash-lite) + 3.5-flash fallback** = `OK`
- [ ] Slack `@mention` → on-brand reply after `/new`
- [ ] Proxy logs (`docker logs google-genai-proxy`): `rewrite … notes=gemini-3.1-flash-lite-preview->gemini-3.1-flash-lite` followed by `HTTP/1.1" 200`
- [ ] Gateway logs: no endless **429** on same model without fallback lines

> Note: `models status` will still **display** `…-preview` in OpenClaw 2026.5.19 — that is the CLI's read-time normalization, not a real config error. The proxy intercepts the URL at the network layer, so the actual API call is correct.

---

## OpenClaw 2026.5.19 normalization bug — root cause + workaround

**Confirmed 2026-05-26** via gateway logs after Phases A–C:

OpenClaw 2026.5.19 contains a baked-in alias map (likely `normalizeGoogleModelId()` in the bundled JS) that rewrites at **runtime, inside the gateway**:

```
google/gemini-3.1-flash-lite -> google/gemini-3.1-flash-lite-preview
```

The rewrite happens **upstream of all config-layer overrides**: it is applied to `agents.defaults.model.primary`, to `agents.defaults.models[<id>]`, and to `models.providers.google.models[].id` *at read time*. Tried and failed: direct `~/.openclaw/openclaw.json` edit, `agents.defaults.models[…].params.model`, `apiModel`, `models aliases remove`. Gateway always outputs:

```
requested=google/gemini-3.1-flash-lite-preview reason=model_not_found
```

`gemini-3.1-flash-lite-preview` was retired by Google → 404 → fallback chain runs.

**Cosmetic side-effect:** `openclaw models status` *always* displays `-preview` even when the on-disk config has the stable id. The CLI applies the same normalization on read. **This is not a real config error** — only a display artifact in OpenClaw 2026.5.19.

### Workaround: URL-rewrite proxy sidecar (in repo)

- Script: [`gcp/vm/google-genai-proxy.py`](../gcp/vm/google-genai-proxy.py) (stdlib HTTP server)
- Deployer: [`gcp/vm/setup-google-genai-proxy.sh`](../gcp/vm/setup-google-genai-proxy.sh) (Docker sidecar on `openclaw_default` network)
- Config: `models.providers.google.baseUrl = "http://google-genai-proxy:8788"` (already in [`model-failover.patch.json5`](../gcp/vm/model-failover.patch.json5) + [`google-provider-models.replace.json5`](../gcp/vm/google-provider-models.replace.json5))

The proxy intercepts outbound `:generateContent` / `:streamGenerateContent` calls, rewrites the URL path back to the stable id, and forwards to Google. It also patches a second OpenClaw bug — the streaming endpoint is issued **without** the required `/v1beta/` prefix (only the non-stream variant includes it) — by prepending `/v1beta` when missing.

### Deploy order (full recovery)

```bash
cd experiments/openclaw-google/gcp
./scripts/start-vm.sh
./vm/setup-google-genai-proxy.sh     # sidecar + standalone HTTP=200 smoke
./vm/setup-model-stack.sh            # patches config with baseUrl + restarts
./scripts/vm-exec.sh bash -s < vm/smoke-openclaw-models.sh   # OpenClaw agent probes
```

### What `models set` does — DON'T run it for the primary

`openclaw models set google/gemini-3.1-flash-lite` writes `…-preview` back into `agents.defaults.model.primary`. The patch in `setup-model-stack.sh` sets `primary` directly without that call — leave it alone. (Same goes for `openclaw doctor --fix`, which may re-normalize.)

### Proxy operations (caveats, sunset, security)

Day-to-day ops, degraded-mode behavior, and the security note for the API key in the URL live in [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md) **§ URL-rewrite proxy**. Highlights:

- **Degraded mode:** proxy down → 3.1 returns 404, all traffic falls over to `gemini-3.5-flash` (20 RPD). Quota burns ~25× faster than 3.1 (500 RPD).
- **Streaming timeout:** `urlopen(timeout=120)` may truncate long SSE streams; bump in [`google-genai-proxy.py`](../gcp/vm/google-genai-proxy.py) if D-prompts cut off mid-reply.
- **Maintenance scope:** `REWRITES` list at the top of the proxy is the only place to add new retired aliases.
- **Sunset:** when an OpenClaw image bump returns `OK` for `google/gemini-3.1-flash-lite` against `agent --local` **without** the proxy in front, remove the sidecar and drop `models.providers.google.baseUrl`.
- **Security:** plain HTTP on docker bridge; `GEMINI_API_KEY` rides in URL query. Acceptable for single-VM class demo only.

## If even the proxy approach is unavailable

**Last-resort temporary stack** until Pacific RPD reset:

- **Primary:** `google/gemini-3.5-flash` only while **RPD &lt; 20** and RPM not pegged
- **No fallbacks** to 2.5* (buckets over limit)
- Reduce demo traffic; wait for reset; or enable billing / tier upgrade

**Longer term:** bump OpenClaw image digest and re-smoke registry; if upstream fixes the alias, the proxy can be removed (delete sidecar, drop `baseUrl` from the google provider).

---

## Files to touch

| File | Role |
|------|------|
| [`gcp/vm/google-genai-proxy.py`](../gcp/vm/google-genai-proxy.py) | URL-rewrite proxy (stdlib HTTP). Edit `REWRITES` to add new retired aliases. |
| [`gcp/vm/setup-google-genai-proxy.sh`](../gcp/vm/setup-google-genai-proxy.sh) | Deploys proxy as Docker sidecar on `openclaw_default`; idempotent. Run **before** `setup-model-stack.sh`. |
| [`gcp/vm/google-provider-models.replace.json5`](../gcp/vm/google-provider-models.replace.json5) | Replaces `models.providers.google` entirely: `api`, `baseUrl` (proxy), and `models[]` registry. |
| [`gcp/vm/model-failover.patch.json5`](../gcp/vm/model-failover.patch.json5) | Primary + fallbacks + allowlist; also includes `baseUrl`. |
| [`gcp/vm/setup-model-stack.sh`](../gcp/vm/setup-model-stack.sh) | Applies both patches and restarts gateway. Intentionally **does not** call `openclaw models set` for the 3.1 primary. |
| [`docs/GEMINI_RATE_LIMITS.md`](./GEMINI_RATE_LIMITS.md) | Live quota + stack + smoke matrix. |
| [`docs/TROUBLESHOOTING.md`](./TROUBLESHOOTING.md) | Proxy operational notes (degraded mode, streaming, sunset, security). |
| [`journal.md`](../journal.md) | Evidence: gateway logs, dates, operator outcomes. |

---

## Fresh-context prompt (copy into new Cursor chat)

```markdown
You are fixing **openclaw-google** Slack replies on GCE. The bot shows "Something went wrong" or stays silent.

**Read first (in order):**
1. `experiments/openclaw-google/docs/MODEL_RECOVERY_PLAN.md` (this plan)
2. `experiments/openclaw-google/docs/TROUBLESHOOTING.md`
3. `experiments/openclaw-google/docs/GEMINI_RATE_LIMITS.md`
4. `experiments/openclaw-google/journal.md` § Current ops snapshot

**Workspace:** `experiments/openclaw-google/gcp/` · VM `openclaw-gateway` · project `REDACTED-gcp-project` · OpenClaw **2026.5.19**

**Live AI Studio quotas (operator snapshot):**
- **Gemini 3.1 Flash Lite:** 9/500 RPD, 2/15 RPM → **use as primary** (API works; AI Studio shows usage)
- **Gemini 3.5 Flash:** 10/20 RPD, 5/5 RPM → fallback only
- **Gemini 2.5 Flash Lite:** 29/20 RPD → **over limit — remove from stack**
- **Gemini 2.5 Flash:** 25/20 RPD → **over limit — remove from stack**

**Root cause hypothesis:**
- Current stack primary/fallbacks target **exhausted** 2.5 buckets and RPM-maxed 3.5.
- **3.1 Flash Lite** has quota but OpenClaw may map `google/gemini-3.1-flash-lite` → retired `gemini-3.1-flash-lite-preview` (404).
- Past failures: 429 on 3.5 without successful failover; `EmbeddedAttemptSessionTakeoverError` → user needs `/new`.
- Requires `models.providers.google.api: "google-generative-ai"` + `models.providers.google.models[]` registry.

**Your task:**
1. Run Phase A–C in MODEL_RECOVERY_PLAN.md on the VM (`start-vm`, API smoke, OpenClaw smoke, fix 3.1 stable id, update `model-failover.patch.json5` + `google-provider-models.replace.json5`, `setup-model-stack.sh`, gateway restart).
2. Verify Slack: `/new` then `@OpenClaw hi` in new thread → Clawde reply.
3. Update GEMINI_RATE_LIMITS.md + journal.md (no secrets).

**Do not:** commit tokens; do not use 2.5-flash / 2.5-flash-lite until RPD resets.

**Success:** `models status` shows no preview alias; smoke-openclaw OK for primary; Slack happy path works.
```
