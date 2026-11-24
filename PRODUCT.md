# Product: Personal agent via Slack

Canonical **product** definition for **openclaw-google**. Operator deploy/harden steps live in [`RUNBOOK.md`](./RUNBOOK.md); implementation details in [`docs/PERSONAL_AGENT.md`](./docs/PERSONAL_AGENT.md).

---

## One-line goal

A **personal agent** on GCE that CS112 students reach **only in Slack** (Socket Mode): message the bot to **start tasks** and **get replies** in-thread—web-assistant *behavior*, not a student-facing web UI.

---

## Definition

> **Personal web assistant:** a cloud-hosted AI helper you message to start tasks (research, summarization, planning, Q&A) and that replies with results—traditionally in a browser; in this course **via Slack only**.

OpenClaw on GCE is the backend; Slack is the front door. Students do not use this repo, the Control UI, or `curl`.

---

## Architecture (3-box)

```text
Surface (Slack)  →  Runtime (OpenClaw on GCE)  →  Model (Gemini + prompt)
```

| Box | Responsibility | Stage focus |
|-----|----------------|-------------|
| **Surface** | Student UX: `@mention`, threads, DMs | Stage 2–3 |
| **Runtime** | VM, Docker, OpenClaw gateway, Slack plugin, channel policy | Stage 1–2, Stage 4 hardening |
| **Model** | API keys, default model, system prompt (persona) | Stage 2–3 |

```text
Slack workspace → Socket Mode (WSS out) → openclaw-gateway (GCE) → Gemini API
```

Operators use [`gcp/scripts/`](./gcp/scripts/) and SSH tunnel for Control UI. Day-to-day fixes: [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md).

---

## Unified stages (human timeline)

Use **Stages 1–4** in README, journal, and demos. Internal RUNBOOK/Product IDs are in [Internal tracking](#internal-tracking) below.

| Stage | Summary | Status |
|-------|---------|--------|
| **Stage 1** — VM + gateway | OpenClaw on GCE, healthz, hardened `gateway.mode` | **Done** |
| **Stage 2** — Slack + Gemini | Socket Mode, `@mention` reply, default model | **Done** |
| **Stage 3** — Persona | Personal-agent system prompt, on-brand first reply | **Done** — `clawde-v1`; [`gcp/vm/setup-persona.sh`](./gcp/vm/setup-persona.sh) |
| **Stage 4** — Class-ready | Hardening, ops, demo pack verification (D1–D5) | **Next** |

**Journal status line template:**

```text
Stage: 3 | Surface: Slack + Clawde persona | Runtime: VM + gateway OK | Model: 2.5-flash; D1–D5 demo pack pending
```

---

## Student experience

1. Student `@mentions` the bot in a channel (or DMs when pairing is configured).
2. Bot acknowledges and replies **in the thread**.
3. Student sends follow-ups in the same thread for multi-turn tasks.

**Primary demo path:** `@mention` (not `/openclaw` slash—may timeout under slow model latency).

---

## Non-goals

- **TA grading bot** or assignment submission integration
- **Security-lesson persona** as the primary UX (for now)
- Student-facing **Control UI** or custom web app
- Archived Cloud Run HTTP starter as the product (see [`archive/MANIFEST.md`](./archive/MANIFEST.md))
- Broad unrestricted tool surface before hardening (see RUNBOOK Phase 2)

---

## CS112 alignment

Students already practice **“do work → deliver in Slack”** in lab A04 (Claude connectors). This agent mirrors that pattern with OpenClaw + Gemini on GCE. See [`docs/CS112_ALIGNMENT.md`](./docs/CS112_ALIGNMENT.md).

---

## Capability roadmap

| Version | Capabilities |
|---------|--------------|
| **Stage 2 (today)** | Conversational Gemini via Slack; sandbox channel policy (`groupPolicy: "open"`) |
| **Stage 3** | Personal-agent system prompt; helpful PA tone and scope |
| **Stage 4** | Demo prompts verified; RUNBOOK Phase 2 hardening + Phase 3 ops |
| **Future** | Tool integrations (Drive, search) — after Stage 3 + Stage 4 |

**Note:** Nine CS112 lecture PDFs on the VM (`course/cs112-*.pdf`) with built-in `read`/`pdf` tools ship before full Drive integration — see [`gcp/vm/setup-course-materials.sh`](./gcp/vm/setup-course-materials.sh).

---

## Not now (explicit deferrals)

- **Stage 3 persona** — separate follow-up plan (not blocked on Stage 4)
- **Tools (Drive, web search)** — after persona + class-ready hardening (VM-local course PDFs are separate)
- **HTTP Slack mode, Cloud Run bridge, TA grading** — archived / non-goals
- **Secret Manager, production allowlists** — Stage 4 / RUNBOOK Phase 2

Prevents unfinished Stage 2 plumbing from looking like a incomplete product.

---

## Success criteria

- First Slack reply is **on-brand** (personal assistant, not generic “who are you?”) — Stage 3
- **3–5 demo prompts** from [`docs/PERSONAL_AGENT.md`](./docs/PERSONAL_AGENT.md) produce useful replies in Slack
- Instructor can demo: **kick off task → get answer in Slack** in under 5 minutes
- No secrets in git; evidence recorded in `journal.md` (names only)

---

## Internal tracking

<details>
<summary>RUNBOOK + Product milestone mapping (operators / agents)</summary>

| Stage | RUNBOOK | Product |
|-------|---------|---------|
| 1 | Phase 0 | — |
| 2 | Phase 1 | P0 plumbing |
| 3 | — | P1 persona |
| 4 | Phase 2 + 3 | P2 demo pack; P3 tools deferred |

</details>

---

## Related documents

| Document | Role |
|----------|------|
| [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md) | Day-to-day operator fixes |
| [`docs/PERSONAL_AGENT.md`](./docs/PERSONAL_AGENT.md) | System prompt, demo pack, verification |
| [`docs/CLASS_DEPLOYMENT.md`](./docs/CLASS_DEPLOYMENT.md) | Phase 1 professor pilot → Phase 2 multi-user (per-student keys) |
| [`docs/CS112_ALIGNMENT.md`](./docs/CS112_ALIGNMENT.md) | Lab patterns this product mirrors |
| [`RUNBOOK.md`](./RUNBOOK.md) | Ops phases 0–3 |
| [`AGENT_HANDOFF.md`](./AGENT_HANDOFF.md) | Agent / chat context prompt |
| [`DEMO.md`](./DEMO.md) | Live presentation scripts |
