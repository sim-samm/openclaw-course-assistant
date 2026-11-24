# Professor pilot — try Clawde in Slack

Short guide for **non-operators** trying the **Phase 1** single-VM pilot. Operators: use the checklist in [`AGENT_HANDOFF.md`](../AGENT_HANDOFF.md) § Professor demo first.

**Product context:** [`PRODUCT.md`](../PRODUCT.md). **Scale-up pitch (later):** [`CLASS_DEPLOYMENT.md`](./CLASS_DEPLOYMENT.md) Phase 2.

---

## What you are trying

**Clawde** 🤖 — a personal web assistant for Generative AI Studio, reached **only in Slack**. You `@mention` the bot in a channel; it replies **in the thread**. No GCP account, repo, or API keys on your side for this pilot.

---

## Before you open Slack (operator confirms)

The gateway runs on a VM that **must be started** for the bot to answer. If messages get no reply after ~30 seconds, contact the operator (Neo / course team).

---

## How to try (5 minutes)

1. Accept the invite to the **teaching Slack workspace** (operator sends invite).
2. Join channel **`#openclaw-test`** (or the channel named in your invite).
3. Start a **new thread** (recommended).
4. Message: `@OpenClaw` then `hi`  
   **Expected:** Clawde introduces itself as a Digital Guide for Generative AI Studio.
5. Optional prompts (same thread):
   - `What can you do?`
   - `Summarize the main topics in Generative AI Studio in 3 bullets.` (demo D1)
   - `Improve this prompt: What are the uses of AI?` (demo D5)

**Prefer `@mention`** over the `/openclaw` slash command (slash may timeout).

---

## Limitations (pilot honesty)

| Topic | Pilot behavior |
|-------|----------------|
| **API usage** | One shared Gemini key on the server — not per-user billing yet |
| **Class size** | Fine for a few testers; full class needs Phase 2 ([`CLASS_DEPLOYMENT.md`](./CLASS_DEPLOYMENT.md)) |
| **Privacy** | Do not paste API keys or passwords in Slack |
| **Availability** | VM may be stopped between sessions to save cost |

---

## If something fails

| Symptom | What to do |
|---------|------------|
| No reply after `@OpenClaw` | Tell operator; they check VM + gateway health |
| “Thinking” but no message | Often quota or model error — operator checks logs |
| Generic “who am I?” onboarding | Old thread — try a **new thread** after persona deploy |

Operator fixes: [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md).

---

## Optional reading (no action required)

- [`PERSONAL_AGENT.md`](./PERSONAL_AGENT.md) — demo prompt pack
- [`CS112_ALIGNMENT.md`](./CS112_ALIGNMENT.md) — how this mirrors lab patterns
