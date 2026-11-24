# OpenClaw course assistant (Clawde)

**Status:** Private portfolio draft — intended for Fairly application review; will flip to public when copy is final.

## What this is

A **Slack-only** teaching assistant for an undergraduate **Generative AI Studio** course: students `@mention` **Clawde** in Slack; replies run **OpenClaw in Docker on GCE**, with **Gemini** as the model provider. No student web UI — help stays in-thread where the class already works.

Built largely by **directing Cursor agents** with a stable ops playbook (`AGENT_HANDOFF.md`), not by hand-writing every script.

## Start here (for reviewers)

| If you want… | Read |
|--------------|------|
| Product scope & guardrails | [`PRODUCT.md`](./PRODUCT.md) |
| How ops + agent handoffs work | [`AGENT_HANDOFF.md`](./AGENT_HANDOFF.md) |
| **Failure + fix** (preview model alias, free-tier quotas) | [`docs/MODEL_RECOVERY_PLAN.md`](./docs/MODEL_RECOVERY_PLAN.md) § context + Phase B–C |
| URL-rewrite **proxy workaround** (no fork) | [`gcp/vm/google-genai-proxy.py`](./gcp/vm/google-genai-proxy.py), [`gcp/vm/setup-google-genai-proxy.sh`](./gcp/vm/setup-google-genai-proxy.sh) |
| Student persona & tools policy | [`gcp/vm/workspace/AGENTS.md`](./gcp/vm/workspace/AGENTS.md), [`SOUL.md`](./gcp/vm/workspace/SOUL.md) |
| Evidence log (scrubbed) | [`journal.md`](./journal.md) — see 2026-05-26 proxy / model stack entries |

## Stack (high level)

```
Slack (Socket Mode) → OpenClaw gateway (Docker) → Gemini API
                              ↑
                    optional google-genai-proxy sidecar
                    (rewrites retired preview model path → stable id)
```

## What is *not* in this repo

- Lecture PDFs, API keys, Slack tokens, or live `.env` files
- Full CS506 monorepo (MCP labs, notebooks, etc.)

## Operator docs

- GCP lifecycle: [`gcp/README.md`](./gcp/README.md)
- Incidents: [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md)
- Demo script: [`DEMO.md`](./DEMO.md)

## Author

Simeon Sammons — CS506 independent study / lab materials context. Private repo until application paragraph is finalized; happy to grant read access on request before public release.