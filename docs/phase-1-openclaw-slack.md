# Phase 1 implementation: Slack + OpenClaw (vendor path)

This document expands **[`RUNBOOK.md`](../RUNBOOK.md) § Phase 1**. If anything here disagrees with upstream, **follow upstream**. Operator bookmarks: **[`openclaw-docs-index.md`](./openclaw-docs-index.md)**.

**Prerequisites:** Phase 0 gateway live and hardened — [`phase-0-openclaw-gcp.md`](./phase-0-openclaw-gcp.md), evidence in [`journal.md`](../journal.md).

## Transport choice (read first)

OpenClaw supports two Slack transports ([Slack channel docs](https://docs.openclaw.ai/channels/slack.md)):

| Transport | Best for this repo’s **GCE VM** | Public HTTPS to VM? | Signing secret |
|-----------|----------------------------------|---------------------|----------------|
| **Socket Mode (default)** | **Yes** — single gateway on VM, outbound WSS to Slack | **Not required** | Not used (App-Level Token auth) |
| HTTP Request URLs | Load-balanced gateways, inbound-only networks | **Required** (`/slack/events` or custom `webhookPath`) | **Required** — OpenClaw verifies Slack signatures |

**Recommendation:** Start with **Socket Mode** on `openclaw-gateway`. Defer HTTP Request URLs unless you need multiple gateway replicas or cannot allow outbound `*.slack.com`.

The original RUNBOOK Phase 1 wording (“Request URL”, “signature-validated”) applies to the **HTTP** path. For Socket Mode, success criteria shift to: valid **bot + app tokens**, plugin installed, config patched, and one **happy-path** message in Slack.

## Canonical upstream

| Resource | URL |
|----------|-----|
| Slack channel | [channels/slack](https://docs.openclaw.ai/channels/slack.md) |
| Plugins | [tools/plugin](https://docs.openclaw.ai/tools/plugin) |
| Doc index | [llms.txt](https://docs.openclaw.ai/llms.txt) |

## What this repo is not doing in Phase 1

- **Cloud Run bridge** — Archived; not required for Socket Mode on the VM. See [`archive/MANIFEST.md`](../archive/MANIFEST.md).
- **Custom signing middleware in git** — OpenClaw handles HTTP signing when you choose Request URL mode; do not reimplement unless you run a separate bridge.

## Operator checklist — Socket Mode (recommended)

Complete on the **VM** (or via [`gcp/scripts/vm-exec.sh`](../gcp/scripts/vm-exec.sh)) after Phase 0 smoke is green. Paste evidence into [`journal.md`](../journal.md) under **RUNBOOK Phase 1 — Slack**.

**Create the Slack app first:** [`SLACK_APP_WALKTHROUGH.md`](./SLACK_APP_WALKTHROUGH.md).

1. **VM running** — `./scripts/start-vm.sh` if stopped; SSH or tunnel works.
2. **Slack plugin** — Per upstream:
   ```bash
   openclaw plugins install @openclaw/slack
   ```
3. **Slack app** — [api.slack.com/apps](https://api.slack.com/apps/new) → create from manifest in [Slack docs](https://docs.openclaw.ai/channels/slack.md) (Socket Mode variant).
4. **Enable Socket Mode** — Slack app settings → Socket Mode → enable.
5. **Tokens (VM only)** — Record **names** in journal, not values:
   - `SLACK_BOT_TOKEN` (`xoxb-...`) — Install App → workspace
   - `SLACK_APP_TOKEN` (`xapp-...`) — App-Level Token with `connections:write`
6. **Configure OpenClaw** — Apply upstream `slack.socket.patch.json5` pattern (SecretRef or env). Example patch lives in repo: [`gcp/vm/slack-socket.patch.json5.example`](../gcp/vm/slack-socket.patch.json5.example). Then:
   ```bash
   openclaw config patch --file ./slack.socket.patch.json5 --dry-run
   openclaw config patch --file ./slack.socket.patch.json5
   ```
7. **LLM / auth (if needed)** — Phase 0 used `--auth-choice skip`; wire a provider per [gateway/authentication](https://docs.openclaw.ai/gateway/authentication.md) before expecting model replies in Slack.
8. **Restart gateway** — Recreate compose stack if config is loaded at gateway start (same absolute compose paths as Phase 0 hardening).
9. **Happy path** — Document one test, e.g. DM or `@OpenClaw` mention → reply in Slack. Redact message content in journal if needed.
10. **Negative check** — One deliberate failure: revoked/wrong app token, plugin not installed, or VM cannot reach `wss-primary.slack.com` — record expected vs actual.

## Operator checklist — HTTP Request URLs (alternate)

Use only if Socket Mode is unsuitable. Requires **public HTTPS** to the gateway (or tunnel product), **Signing Secret**, and manifest URLs pointing at your `webhookPath` (default `/slack/events`). Full steps: [Slack channel — HTTP Request URLs](https://docs.openclaw.ai/channels/slack.md).

Record in journal: public URL pattern (no tokens), signing secret **name** only, and verification that tampered requests fail (RUNBOOK Phase 1 criterion for this path).

## Artifacts to record in `journal.md`

| Field | Example (no secrets) |
|-------|----------------------|
| Date / timezone | |
| Transport | `socket` or `http` |
| Slack app name / app ID | |
| Workspace name (not token) | |
| Token env var **names** | `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`, or `SLACK_SIGNING_SECRET` |
| OpenClaw config patch file | e.g. `slack.socket.patch.json5` |
| Happy-path test | Who messaged where; reply observed Y/N |
| Negative check | Scenario; expected vs actual |

## Rollback

- **Disable Slack channel** — `openclaw config` patch to set `channels.slack.enabled: false` (or remove patch file) and restart gateway.
- **Revoke Slack tokens** — Slack app settings / reinstall; rotate env on VM.
- **Phase 0 only** — Stop using Slack does not require VM delete; see Phase 0 rollback in [`phase-0-openclaw-gcp.md`](./phase-0-openclaw-gcp.md).

## Handoff to Phase 2 (hardening)

When Phase 1 is green:

- Secrets only on VM or Secret Manager; none in git.
- Re-read [Gateway security](https://docs.openclaw.ai/gateway/security) with Slack live (pairing, channel allowlists, abuse).
- Proceed to **`RUNBOOK.md` Phase 2** (timeouts, idempotency, failure injection).
- Configure personal-agent persona per [`PRODUCT.md`](../PRODUCT.md) and [`docs/PERSONAL_AGENT.md`](./PERSONAL_AGENT.md) (Product P1).

**Phase 1 closure:** [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md). Historical narrative: [`archive/MANIFEST.md`](../archive/MANIFEST.md).
