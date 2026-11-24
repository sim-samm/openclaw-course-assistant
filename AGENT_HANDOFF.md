# Agent handoff — openclaw-google

Copy the **prompt block** below into a new Cursor chat (or `@` this file). Update this file when major milestones change.

**Product definition:** [`PRODUCT.md`](./PRODUCT.md)

---

## Professor demo first (default priority)

Use this checklist **before** broad Stage 4 work unless the user explicitly asks otherwise. Professor handout: [`docs/PROFESSOR_PILOT.md`](./docs/PROFESSOR_PILOT.md).

### Operator — before professor opens Slack

- [ ] VM running: `cd experiments/openclaw-google/gcp && ./scripts/start-vm.sh`
- [ ] Health: `./scripts/vm-exec.sh curl -sS http://127.0.0.1:18789/healthz` → `{"ok":true,"status":"live"}`
- [ ] Persona on VM (if drifted): `./vm/setup-persona.sh` (includes retiring `BOOTSTRAP.md`)
- [ ] Course PDFs on VM: `cd vm/course-materials && ./prep-pdfs-for-openclaw.sh` then `./vm/setup-course-materials.sh` (nine `cs112-*.pdf` in `course/`)
- [ ] Operator smoke: **new thread** in `#openclaw-test` → `@OpenClaw` `hi` → Clawde intro (not “Who am I?”)
- [ ] Slack: professor **invited to teaching workspace** (do **not** ask them to create/install their own app for pilot)
- [ ] Slack: professor added to **`#openclaw-test`** (or document alternate channel in invite email)
- [ ] Bot invited to that channel if required by workspace policy
- [ ] Shared Gemini quota acceptable today ([`docs/GEMINI_RATE_LIMITS.md`](./docs/GEMINI_RATE_LIMITS.md))
- [ ] Send professor [`docs/PROFESSOR_PILOT.md`](./docs/PROFESSOR_PILOT.md) (or paste its “How to try” section) + agreed **VM uptime window**
- [ ] **Do not send** tokens, `phase0.env`, or `~/openclaw/.env` contents

### Operator — during / after demo

- [ ] If no reply: [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md) (socket, model 429, channel policy)
- [ ] Record in `journal.md`: date, professor tried Y/N, one-line outcome (no secrets)
- [ ] `./scripts/stop-vm.sh` when done for the day (optional cost save)

### Defer until after professor feedback

- Full RUNBOOK Phase 2/3, D1–D6 pack (incl. grounded PDF demos), channel allowlist hardening, PR → `main`, Phase 2 multi-agent ([`docs/CLASS_DEPLOYMENT.md`](./docs/CLASS_DEPLOYMENT.md))

---

## Prompt (copy from here)

```markdown
You are continuing development on **openclaw-google** in the CS506 repo.

**Workspace:** `experiments/openclaw-google/` (branch **`feat/openclaw-gcp`**, not necessarily merged to `main`).

**Product goal:** A **personal agent** for students on **Slack only** (Socket Mode): they message the bot to **start tasks** and **get replies** in-thread—like a lightweight personal web assistant, with no other student-facing surface. OpenClaw gateway on **GCE**. Historical Cloud Run lab track is in [`archive/MANIFEST.md`](./archive/MANIFEST.md).

See [`PRODUCT.md`](./PRODUCT.md) for Stages 1–4 and 3-box model (Surface / Runtime / Model).

**Default priority:** **Fix Slack model path** — bot not replying; follow [`docs/MODEL_RECOVERY_PLAN.md`](./docs/MODEL_RECOVERY_PLAN.md) (quota shows **3.1 Flash Lite** has headroom; 2.5* buckets over RPD). Then professor demo ([`docs/PROFESSOR_PILOT.md`](./docs/PROFESSOR_PILOT.md)).

**Current status (Stages):** Stages 1–3 **done**. Stage 4 (class-ready hardening + ops) **next**. VM may be TERMINATED — `./gcp/scripts/start-vm.sh` before demos.

### What is DONE

- **Stage 1** — VM `openclaw-gateway` (`REDACTED-gcp-project`, `us-central1-a`); Docker Compose; `gateway.mode=local`; hardened (no `--allow-unconfigured`). Scripts: `gcp/scripts/`, `gcp/vm/`.
- **Stage 2** — Slack Socket Mode; `@mention` → reply verified. **Model stack (2026-05-26 evening):** `3.1-flash-lite` primary (500 RPD) via URL-rewrite proxy sidecar → fallback `3.5-flash`. Proxy works around the OpenClaw 2026.5.19 baked-in alias (`gemini-3.1-flash-lite -> -preview` → 404) — see [`docs/MODEL_RECOVERY_PLAN.md`](./docs/MODEL_RECOVERY_PLAN.md). Deploy order: [`gcp/vm/setup-google-genai-proxy.sh`](./gcp/vm/setup-google-genai-proxy.sh) **then** [`gcp/vm/setup-model-stack.sh`](./gcp/vm/setup-model-stack.sh). Golden Slack: `gcp/vm/setup-slack-socket.sh`.
- **Stage 3** — Persona **`clawde-v1`**: [`gcp/vm/workspace/`](./gcp/vm/workspace/) + [`gcp/vm/setup-persona.sh`](./gcp/vm/setup-persona.sh) (retires `BOOTSTRAP.md`). On-brand Slack intro verified 2026-05-25.
- **OpenClaw image:** `ghcr.io/openclaw/openclaw@sha256:8ecbd44d788db7048108a712802a98fad3f1f9a8a87f78fb111dc3fd0f8a9ed7` (2026.5.19).

### What is NOT done

- **Professor pilot** — checklist in AGENT_HANDOFF § Professor demo first (invite, VM window, handout sent).
- **Stage 4** — RUNBOOK Phase 2 hardening + Phase 3 ops; **D1–D6** demo pack verification ([`docs/PERSONAL_AGENT.md`](./docs/PERSONAL_AGENT.md)).
- **Course materials on VM** — scripts in repo; operator must run `setup-course-materials.sh` + Slack smoke (D1/D6).
- **`/openclaw` slash** — may timeout; prefer `@mention`.
- **DM pairing** — not fully tested.

### Secrets (critical)

- **Never commit:** `gcp/phase0.env`, VM `~/openclaw/.env`, tokens, API keys.
- Use `gcp/scripts/vm-exec.sh`; record secret **names** only in `journal.md`.

### Operator commands (from `experiments/openclaw-google/gcp/`)

```bash
./scripts/start-vm.sh
./scripts/stop-vm.sh
./scripts/vm-exec.sh curl -sS http://127.0.0.1:18789/healthz
./scripts/ssh-tunnel.sh
export SLACK_APP_TOKEN='...' SLACK_BOT_TOKEN='...' GEMINI_API_KEY='...'
./vm/setup-slack-socket.sh
./vm/setup-persona.sh
./vm/setup-course-materials.sh     # cs112-*.pdf + read/pdf tools
./vm/setup-google-genai-proxy.sh   # required for 3.1-flash-lite primary
./vm/setup-model-stack.sh          # run after the proxy is up
```

### Canonical read order (model recovery)

1. [`docs/MODEL_RECOVERY_PLAN.md`](./docs/MODEL_RECOVERY_PLAN.md) — **start here if Slack broken**
2. [`docs/GEMINI_RATE_LIMITS.md`](./docs/GEMINI_RATE_LIMITS.md)
3. [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md)
4. [`AGENT_HANDOFF.md`](./AGENT_HANDOFF.md) § Professor demo first
5. [`docs/PROFESSOR_PILOT.md`](./docs/PROFESSOR_PILOT.md)
3. `journal.md` § Current ops snapshot
4. [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md)
5. `PRODUCT.md`, `docs/CLASS_DEPLOYMENT.md`, `RUNBOOK.md` as needed

### Class deployment (phased)

| Phase | Goal |
|-------|------|
| **1 (now)** | Professor try-out: **single VM + shared key**, invite to **existing** Slack workspace |
| **2 (later)** | Multi-agent per-student keys — pitch after feedback ([`docs/CLASS_DEPLOYMENT.md`](./docs/CLASS_DEPLOYMENT.md)) |

### Suggested next work (unless user overrides)

1. **Professor demo** — complete AGENT_HANDOFF checklist; send `PROFESSOR_PILOT.md`.
2. **Stage 4 hardening** — allowlist channel, ops triage (after pilot or in parallel if time).
3. **Demo pack** — D1–D5 when Gemini quota allows.
4. **PR merge** `feat/openclaw-gcp` → `main` when ready.

**Deferred:** [`docs/GEMINI_RATE_LIMITS.md`](./docs/GEMINI_RATE_LIMITS.md) § Future tasks; Phase 2 provisioning scripts.

### Conventions

- Follow existing bash/gcp script style; minimal diffs.
- Do not commit unless user asks.
- Upstream wins over repo docs when they conflict.

Start with [`docs/MODEL_RECOVERY_PLAN.md`](./docs/MODEL_RECOVERY_PLAN.md) if Slack returns errors or no reply.
```

---

## Quick reference

| Item | Value |
|------|--------|
| GCP project | `REDACTED-gcp-project` |
| VM | `openclaw-gateway` @ `us-central1-a` |
| Working dir for gcloud | `experiments/openclaw-google/gcp/` |
| Branch | `feat/openclaw-gcp` |
| Stage | 1–3 done; **4 next**; **pilot first** |
| Demo channel | `#openclaw-test` (verify in journal) |
| Default LLM (VM) | `google/gemini-3.1-flash-lite` (via proxy) → `gemini-3.5-flash` |
| Model stack scripts | `./vm/setup-google-genai-proxy.sh` then `./vm/setup-model-stack.sh` |
| Persona | `clawde-v1` — `gcp/vm/workspace/` |

## Key files

| Path | Role |
|------|------|
| `docs/PROFESSOR_PILOT.md` | Professor-facing try-out (send this) |
| `PRODUCT.md` | Stages 1–4, 3-box model |
| `docs/TROUBLESHOOTING.md` | Day-to-day fixes |
| `RUNBOOK.md` | Ops phases 0–3 |
| `docs/PERSONAL_AGENT.md` | Persona + demo pack |
| `gcp/vm/setup-slack-socket.sh` | Golden Slack + model setup |
| `gcp/vm/setup-google-genai-proxy.sh` | Deploys URL-rewrite proxy (workaround for 2026.5.19 alias bug) |
| `gcp/vm/setup-model-stack.sh` | Applies model failover + provider registry patches |
| `gcp/vm/setup-persona.sh` | Stage 3 persona deploy |
| `docs/MODEL_RECOVERY_PLAN.md` | Root cause + recovery for "Something went wrong" / silent Slack |
| `docs/CLASS_DEPLOYMENT.md` | Class phases 1–2 (pilot vs multi-agent) |
| `journal.md` | Evidence + snapshot |

## Architecture (3-box)

```text
Surface (Slack) → Runtime (OpenClaw GCE) → Model (Gemini + prompt)
```
