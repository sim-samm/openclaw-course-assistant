# Journal: openclaw-google

## Context

Primary operator spine: **[`RUNBOOK.md`](./RUNBOOK.md)**. **Product:** [`PRODUCT.md`](./PRODUCT.md). **Fixes:** [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md). **Demo:** [`DEMO.md`](./DEMO.md).

### Current ops snapshot (2026-05-25)

**Stage:** 3 **done** (`clawde-v1`) | **Priority:** Professor pilot ([`AGENT_HANDOFF.md`](./AGENT_HANDOFF.md) § Professor demo first) | **Then:** Stage 4 hardening + D1–D5 when quota allows

| Box | State |
|-----|--------|
| **Surface** (Slack) | Socket Mode wired; Clawde on-brand intro verified (2026-05-25); D1–D5 / DM pairing deferred |
| **Runtime** (GCE + gateway) | **VM RUNNING** (2026-05-25 cycle); `/healthz` live; containers healthy; image **2026.5.19**; persona on VM (`BOOTSTRAP` retired) |
| **Model** (Gemini) | **Primary** `google/gemini-3.1-flash-lite` (500 RPD) via URL-rewrite proxy sidecar → fallback `google/gemini-3.5-flash` (20 RPD); [`setup-google-genai-proxy.sh`](./gcp/vm/setup-google-genai-proxy.sh) + [`setup-model-stack.sh`](./gcp/vm/setup-model-stack.sh) — [`docs/MODEL_RECOVERY_PLAN.md`](./docs/MODEL_RECOVERY_PLAN.md), [`docs/GEMINI_RATE_LIMITS.md`](./docs/GEMINI_RATE_LIMITS.md) |

**Operator pre-flight (2026-05-25):** `start-vm` N/A (already RUNNING) · `healthz` OK · persona files present · model primary confirmed · Slack smoke + professor invite/handout **pending operator**.

Resume: `./gcp/scripts/start-vm.sh` before demos if VM stopped. Defer broad Stage 4 until after professor feedback unless time allows in parallel. Class scale → [`docs/CLASS_DEPLOYMENT.md`](./docs/CLASS_DEPLOYMENT.md) Phase 2.

### Professor pilot log (no secrets)

| Date | Professor tried | Outcome |
|------|-----------------|--------|
| 2026-05-25 | Y (Wu-chang) | Happy path in Slack — “Works great!”; asked for student background slides |
| 2026-05-30 | Y (operator) | Class workspace `pdx-cs` / `#cs112` — `@OpenClaw` reply after model stack fix |

### Incident — Slack-only setup, model silent next day (2026-05-30)

**Symptom:** Bot worked after `pdx-cs` Slack install; **no model reply** the following day. Slack socket still connected.

**Cause:** Only [`gcp/vm/setup-slack-socket.sh`](./gcp/vm/setup-slack-socket.sh) run (no [`setup-model-stack.sh`](./gcp/vm/setup-model-stack.sh)). VM drifted to **primary + fallback `google/gemini-3.5-flash`** (20 RPD shared). Quota exhausted overnight; no failover to 3.1 (500 RPD).

**Fix:** `./vm/setup-google-genai-proxy.sh` + `./vm/setup-model-stack.sh` → `@OpenClaw` OK in `#cs112`.

**Prevention:** Golden path in [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md) § Golden recovery; removed `models set` from `setup-slack-socket.sh`.

### Course materials on VM (operator checklist)

Repo ships [`gcp/vm/setup-course-materials.sh`](./gcp/vm/setup-course-materials.sh), [`course-tools.patch.json5`](./gcp/vm/course-tools.patch.json5), and nine local `cs112-*.pdf` under [`gcp/vm/course-materials/`](./gcp/vm/course-materials/) (gitignored). Record pass/fail after deploy:

| Step | Done | Notes |
|------|------|-------|
| `prep-pdfs-for-openclaw.sh` (if needed) | Y | 9 `cs112-*.pdf` local |
| `setup-course-materials.sh` | Y | 2026-06-01; 9 PDFs ~44 MB in `~/.openclaw/workspace/course/`; `course-tools.patch.json5` applied (5 updates) |
| `setup-persona.sh` | Y | 2026-06-01; IDENTITY/SOUL/USER/AGENTS/TOOLS on VM |
| VM healthz after restart | Y | `{"ok":true,"status":"live"}` (wait ~20s post-recreate) |
| `sandbox explain` | Y | global allow: `read`, `pdf`; mode `off` on main |
| Slack: list `course/` filenames | | operator |
| Slack: D1 grounded (`cs112-01-models-prompts.pdf`) | | operator |
| Slack: D6 quiz (`cs112-04-agents.pdf`) | | operator |

## Runbook evidence template (fill per milestone)

Use this for **Slack + OpenClaw** work. Paste excerpts without secret values.

| Field | Notes |
|-------|--------|
| Date / TZ | |
| RUNBOOK phase | 0 OpenClaw deploy / 1 Slack / 2 hardening / 3 cost-ops |
| Stage | 1–4 (see [`PRODUCT.md`](./PRODUCT.md)) |
| OpenClaw revision or image digest | |
| OpenClaw base URL (redact query tokens) | |
| Slack app ID / workspace (no tokens) | |
| Smoke or happy-path test | What was sent, where the reply appeared |
| Rollback or follow-up | |

### Product milestones (fill when persona / demo pack ships)

_Use [`docs/PERSONAL_AGENT.md`](./docs/PERSONAL_AGENT.md) verification checklist. Do not paste secrets or full message transcripts if sensitive._

| Field | Notes |
|-------|--------|
| Date / TZ | |
| Product milestone | P1 persona / P2 demo pack / P3 tools |
| Persona version | e.g. git tag, file name, or `personal-agent-v1` |
| Model id | e.g. `google/gemini-3.1-flash-lite` (may show as `…-preview` in config) |
| Demo prompts verified | D1–D5 IDs from PERSONAL_AGENT.md; pass/fail per prompt |
| Slack UX | Thread reply Y/N; DM pairing Y/N; `@mention` primary path confirmed |
| Blockers | e.g. slash timeout, no Drive tool yet |

### RUNBOOK Phase 0 — OpenClaw on GCP (fill when gateway is live)

_Use [`docs/phase-0-openclaw-gcp.md`](./docs/phase-0-openclaw-gcp.md), optional automation [`gcp/README.md`](./gcp/README.md), and [OpenClaw on GCP](https://docs.openclaw.ai/install/gcp). Do not paste secrets._

- **Status:** Phase 0 **gateway hardened (no bootstrap flag)** — **`gateway.mode=local`** set via `openclaw onboard --non-interactive … --accept-risk` (see [`gcp/vm/onboard-noninteractive-local.sh`](./gcp/vm/onboard-noninteractive-local.sh) + [`gcp/README.md`](./gcp/README.md) **Harden**). **`--allow-unconfigured`** removed from compose and stack recreated; **`/healthz`** still **HTTP 200** / `live` (2026-05-13).
- **Date / TZ:** 2026-05-11 VM + Docker + image pull; **2026-05-12** compose + health smoke.
- **GCP project id:** `REDACTED-gcp-project`
- **VM:** `openclaw-gateway` — `us-central1-a` — `e2-small` — 20 GB boot disk — Debian 12 (bookworm) image family `debian-12`
- **OpenClaw version:** container image digest `sha256:1af3f457a2d5a1d210f4d95634fa5da6e23f9c0ac7b52ef4bc38e2ecf09704fd` (pinned in VM `~/openclaw/.env` as `OPENCLAW_IMAGE=…@sha256:…`). Shallow clone **`a6892a5af33867019886408740d097201528e455`** at `/home/operator/openclaw` (for `docker-compose.yml` + patch).
- **Access:** SSH `gcloud compute ssh openclaw-gateway --zone=us-central1-a --project=REDACTED-gcp-project`. Control UI: from repo `experiments/openclaw-google/gcp`, `./scripts/ssh-tunnel.sh` then browser `http://127.0.0.1:18789/` (token in VM `~/openclaw/.env` as `OPENCLAW_GATEWAY_TOKEN` — **not recorded here**).
- **Smoke test:** (1–3) as 2026-05-11. **(4)** On VM after compose: `curl -sS -i http://127.0.0.1:18789/healthz` → **HTTP 200** body `{"ok":true,"status":"live"}`.
- **Rollback:** `gcp/scripts/stop-vm.sh` / `delete-vm.sh`; `sudo docker compose … down` on VM; re-pin prior image digest in `.env`.
- **Negative check:** (prior) `vm-exec` + `sudo docker` quoting — use `./scripts/vm-exec.sh sudo docker …`.
- **Notes / blockers:** VM `~/openclaw/.env` holds `GOG_KEYRING_PASSWORD` + `OPENCLAW_GATEWAY_TOKEN` (generated on VM, **never committed**). Bootstrap used [`gcp/vm/patch-compose-allow-unconfigured.sh`](./gcp/vm/patch-compose-allow-unconfigured.sh); **do not remove** that flag until `gateway.mode` is set (onboard or manual). **Recovery:** [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md). **Next:** optional bind/firewall tightening per [Gateway security](https://docs.openclaw.ai/gateway/security), then **RUNBOOK Phase 1** Slack.

### RUNBOOK Phase 1 — Slack (fill when channel is live)

_Use [`docs/phase-1-openclaw-slack.md`](./docs/phase-1-openclaw-slack.md). Finish Slack app + tokens via [`docs/SLACK_APP_WALKTHROUGH.md`](./docs/SLACK_APP_WALKTHROUGH.md), then `./gcp/vm/setup-slack-socket.sh`. Do not paste secrets._

- **Status:** **Complete** — Socket Mode connected; **`@OpenClaw` mention in channel → bot reply** verified (2026-05-22). Recovery: [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md).
- **Date / TZ:** 2026-05-21 prep; 2026-05-22 Slack app + wiring + troubleshooting + happy path.
- **Transport:** `socket`
- **Slack app ID / name:** OpenClaw app (from manifest); record App ID from Slack **Basic Information** if needed for support tickets.
- **Workspace:** Teaching workspace (operator-configured; name not recorded here).
- **Token env var names (no values):** `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`, `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `ANTHROPIC_API_KEY` on VM `~/openclaw/.env`
- **Config patch:** Applied to `~/.openclaw/openclaw.json` (`channels.slack` socket mode + `plugins.entries.slack.enabled`). Initial `setup-slack-socket.sh` run stopped at “plugin already exists” before patch/restart — fixed manually 2026-05-22.
- **OpenClaw upgrade:** Image bumped `2026.5.7` → **`2026.5.19`** — `OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw@sha256:8ecbd44d788db7048108a712802a98fad3f1f9a8a87f78fb111dc3fd0f8a9ed7` (required for `@openclaw/slack` plugin).
- **Prep completed:** `@openclaw/slack` plugin installed; gateway `/healthz` **200** after upgrade + restart.
- **LLM auth:** Default model **`google/gemini-2.5-flash-lite`** (2026-05-22); `GEMINI_API_KEY` + `GOOGLE_API_KEY` on VM. Prior failure: default was **`openai/gpt-5.5`** with **no OpenAI key** — agent could not reply in Slack. **2026-05-25:** switched default to **`google/gemini-3.1-flash-lite`** after Free-tier RPD exhaustion on 2.5 Lite — see [`docs/GEMINI_RATE_LIMITS.md`](./docs/GEMINI_RATE_LIMITS.md).
- **Channel policy:** `groupPolicy: "open"`, `dmPolicy: "open"` (sandbox); prior **allowlist** default blocked `#openclaw-test` mentions silently.
- **Happy-path test:** `@OpenClaw` in `#openclaw-test` (channel mention) → **reply observed** in thread/channel (2026-05-22).
- **Negative check:** (1) Plugin on 2026.5.7 rejected — upgraded to 2026.5.19. (2) Missing `SLACK_*` → SecretRef dry-run error (expected). (3) `openai/gpt-5.5` without OpenAI key → no reply until Gemini set. (4) `groupPolicy: allowlist` → silent drop until `open` policy patch.
- **Notes / blockers:** `/openclaw` may still timeout on slow runs — prefer `@mention` for demos. DMs may need **pairing** if tested later. **Recovery:** [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md).

### Model default change — Gemini rate limits (2026-05-25)

_AI Studio Free tier project `REDACTED-gcp-project`; no secret values._

- **Issue:** `@mention` showed thinking but no reply; gateway logs `429 RESOURCE_EXHAUSTED` on `gemini-2.5-flash-lite`.
- **Cause:** Peak **RPD 29/20** on 2.5 Flash Lite (RPM/TPM within limits). See [`docs/GEMINI_RATE_LIMITS.md`](./docs/GEMINI_RATE_LIMITS.md).
- **Change:** Default model → **`google/gemini-3.1-flash-lite`** (Free tier **15 RPM**, **500 RPD**). Golden script [`gcp/vm/setup-slack-socket.sh`](./gcp/vm/setup-slack-socket.sh) updated.
- **Verify:** `@OpenClaw` in test channel after `models set` + gateway restart; no new `429` in bounded logs.

### Model 404 — 3.1 Flash Lite preview retired (2026-05-25)

- **Symptom:** `@mention` / DM (“what's up”) — thinking, no reply.
- **Logs:** `404 NOT_FOUND` — `models/gemini-3.1-flash-lite-preview is no longer available`.
- **Fix:** Default → **`google/gemini-3.5-flash`**; gateway recreated. Do not set `gemini-3.1-flash-lite` until OpenClaw uses a non-preview API id.

### Model registry + API smoke (2026-05-25)

- **3.5-flash:** OpenClaw `Unknown model` (not in runtime provider registry) — user-visible error in Slack.
- **2.5-flash-lite / 2.0-flash-lite:** Direct Gemini API **429** on project.
- **2.5-flash:** Direct API **HTTP 200**; default reset to **`google/gemini-2.5-flash`** + gateway recreate.

### Text-chat smoke + failover stack (2026-05-25)

- **Smoke order:** highest RPD first ([`gcp/vm/smoke-gemini-chat-models.sh`](./gcp/vm/smoke-gemini-chat-models.sh)).
- **API 200:** `gemini-3.1-flash-lite` (500 RPD), `gemini-3.5-flash`, `gemini-2.5-flash`. **429:** 2.5/2.0 lite. **404:** 3.1-preview, 3-flash.
- **OpenClaw:** 3.1-lite → preview alias broken; **runtime** primary `google/gemini-3.5-flash`, fallback `google/gemini-2.5-flash` via [`gcp/vm/model-failover.patch.json5`](./gcp/vm/model-failover.patch.json5).
- **Defer:** 3.1-flash-lite until OpenClaw uses stable API id (best Free-tier RPD).

### Slack persona onboarding (2026-05-25)

- **Happy path:** `@mention` → multi-turn reply after fallback notice.
- **Fallback observed:** `Model Fallback: google/gemini-2.5-flash (selected google/gemini-3.5-flash; model not found)` — confirms 3.5 not in OpenClaw registry; 2.5-flash answers.
- **Manual Slack setup (superseded):** Clawde / Digital Guide / 🤖; operator Neo; freshman AI Agent class web assistant. Formalized in repo — do not continue setup via Slack (quota).
- **Config follow-up:** Primary set to **`2.5-flash`** only in [`gcp/vm/model-failover.patch.json5`](./gcp/vm/model-failover.patch.json5) to avoid repeated fallback notices.

### Stage 3 persona — clawde-v1 (2026-05-25)

- **Persona version:** `clawde-v1`
- **Files:** [`gcp/vm/workspace/`](./gcp/vm/workspace/) — `IDENTITY.md`, `USER.md`, `SOUL.md`, `AGENTS.md`
- **Deploy:** [`gcp/vm/setup-persona.sh`](./gcp/vm/setup-persona.sh) → `~/.openclaw/workspace/` + gateway restart
- **Verify:** New Slack thread `@OpenClaw` — on-brand intro (not “Who am I?”); demo D1–D5 per [`docs/PERSONAL_AGENT.md`](./docs/PERSONAL_AGENT.md)
- **VM deploy evidence:** 2026-05-25 — `setup-persona.sh` wrote workspace files; `BOOTSTRAP.md` retired; gateway `/healthz` live after restart
- **Smoke (2026-05-25):** `hi` in new thread → “Hi REDACTED! I'm Clawde 🤖, your Digital Guide for Generative AI Studio…” — **on-brand** ✓ (Slack also showed suggested prompts: What can you do? / Summarize channel / Draft reply)

### Model failover stack — multi-model RPD (2026-05-26)

- **Issue:** `gemini-2.5-flash` **429**; single-model stack exhausted daily quota.
- **API smoke:** **200** on `3.1-flash-lite`, `2.5-flash-lite`, `3.5-flash`; **429** on `2.5-flash`.
- **Fix:** [`gcp/vm/model-failover.patch.json5`](./gcp/vm/model-failover.patch.json5) + [`google-provider-models.replace.json5`](./gcp/vm/google-provider-models.replace.json5) via [`setup-model-stack.sh`](./gcp/vm/setup-model-stack.sh) — `models.providers.google.api: google-generative-ai`, provider `models[]` registry, fallbacks for separate RPD buckets (~**60**/day on three 20-RPD models).
- **OpenClaw verify:** `3.5-flash` + `2.5-flash-lite` agent probes **OK**; failover chain exercised in logs.
- **Deferred:** `3.1-flash-lite` (500 RPD) — OpenClaw still aliases to retired preview.

### Model recovery — 3.1-flash-lite unblocked via URL-rewrite proxy (2026-05-26 evening)

_AI Studio Free tier project `REDACTED-gcp-project`; no secret values._

- **Live quotas (operator snapshot):** `3.1-flash-lite` 9/500 RPD (best headroom), `3.5-flash` 10/20 RPD, `2.5-flash-lite` 29/20 (over), `2.5-flash` 25/20 (over) — old stack targeted exhausted buckets.
- **Root cause confirmed:** OpenClaw 2026.5.19 contains a baked-in alias map that rewrites `google/gemini-3.1-flash-lite -> google/gemini-3.1-flash-lite-preview` inside the gateway runtime, ahead of all config-layer overrides. Verified by gateway log `requested=google/gemini-3.1-flash-lite-preview reason=model_not_found` despite a direct-edited `openclaw.json` with the stable id. `params.model` override did not bypass it.
- **Workaround:** URL-rewrite proxy sidecar [`gcp/vm/google-genai-proxy.py`](./gcp/vm/google-genai-proxy.py) deployed by [`gcp/vm/setup-google-genai-proxy.sh`](./gcp/vm/setup-google-genai-proxy.sh) on the `openclaw_default` Docker network. OpenClaw points at it via `models.providers.google.baseUrl = http://google-genai-proxy:8788`. Proxy (a) rewrites `-preview` → stable in the URL path; (b) prepends `/v1beta` for OpenClaw's stream endpoint which omits it.
- **Stack:** primary `google/gemini-3.1-flash-lite` (500 RPD via proxy), fallback `google/gemini-3.5-flash`. 2.5-* removed until midnight Pacific reset.
- **Evidence:** proxy logs show `rewrite ... notes=gemini-3.1-flash-lite-preview->gemini-3.1-flash-lite,prefix-v1beta` then `HTTP/1.1" 200`; `agent --local --message "Reply with exactly: OK"` returned `OK`.
- **Slack happy path (2026-05-25 23:31 PT):** `/new` + new thread `@OpenClaw` → Clawde reply confirmed by operator.
- **Cosmetic carry-over (not a defect):** `openclaw models status` displays `…-preview` because the CLI applies the same normalization on read; on-disk config has the stable id and the proxy makes the real API call to the stable model.
- **Follow-up:** [`docs/MODEL_RECOVERY_PLAN.md`](./docs/MODEL_RECOVERY_PLAN.md) full root-cause notes; file upstream OpenClaw issue with the gateway log evidence; remove sidecar + `baseUrl` when upstream fix lands.

---

## Historical evidence (archived)

Cloud Run lab track journal entries (2026-05-11) moved to [`archive/MANIFEST.md`](./archive/MANIFEST.md) (`journal-historical/journal-historical-2026-05.md` inside the tarball). Not part of the active personal-agent path.

## Next steps

- **Product path:** Follow [`RUNBOOK.md`](./RUNBOOK.md) (OpenClaw on GCP → Slack via [`docs/phase-1-openclaw-slack.md`](./docs/phase-1-openclaw-slack.md) → hardening → cost/ops). Upstream bookmarks: [`docs/openclaw-docs-index.md`](./docs/openclaw-docs-index.md).
- **Stage 3:** Persona per [`docs/PERSONAL_AGENT.md`](./docs/PERSONAL_AGENT.md).
