# Runbook: OpenClaw for students via Slack (GCP)

Canonical operator guide for hosting **OpenClaw on Google Cloud** with **Slack** as the only student-facing surface. Students do not use this repo or `curl` checks.

For optional **GCP + Cloud Run smoke test** code (minimal HTTP starter), see [`archive/MANIFEST.md`](./archive/MANIFEST.md).

For the archived **CS475-style lab track** (phased starter, `/openclaw/ping` spike, lab translation), see [`archive/MANIFEST.md`](./archive/MANIFEST.md).

---

## Goals and boundaries

### Goal

- Deliver a **personal agent via Slack** for CS112 students: message the bot to start tasks and get replies in-thread. Full product definition: **[`PRODUCT.md`](./PRODUCT.md)**.
- OpenClaw runs on GCP per **vendor / upstream** documentation.
- A **Slack app** delivers messages to OpenClaw so students interact **only in Slack** (no repo, no Control UI).

### Product milestones (parallel to ops phases)

Track product progress separately from RUNBOOK phases. Details in [`PRODUCT.md`](./PRODUCT.md).

| Milestone | Summary |
|-----------|---------|
| **P0** | Slack → OpenClaw → Gemini reply (plumbing) |
| **P1** | Personal-agent system prompt / persona |
| **P2** | Demo prompt pack + Slack UX verification |
| **P3** | Tools (Drive, search) — future |

Implementer guide: [`docs/PERSONAL_AGENT.md`](./docs/PERSONAL_AGENT.md). CS112 patterns: [`docs/CS112_ALIGNMENT.md`](./docs/CS112_ALIGNMENT.md).

### Non-goals (for this runbook)

- TA grading via `curl /live` or student-facing exercise steps (see archive lab track if needed).
- Building a full MCP server or broad tool surface in this repo unless OpenClaw’s docs require it.

### Trust boundaries (high level)

```text
Slack workspace → HTTPS (Events API) → [optional Slack bridge] → OpenClaw (GCP)
```

Treat **Slack request signing** and **minimal public routes** as the primary internet-facing controls unless OpenClaw’s deployment already encapsulates them.

---

## Phase 0: OpenClaw runs on GCP (vendor path)

### Objective

OpenClaw **Gateway** is **deployed, reachable, and versioned** using the approach documented by the OpenClaw project—not the archived Cloud Run HTTP starter (see [`archive/MANIFEST.md`](./archive/MANIFEST.md)).

### Canonical upstream (read first)

**Primary GCP path:** [OpenClaw on GCP](https://docs.openclaw.ai/install/gcp) — **Compute Engine VM + Docker**, persistent state on the VM, Control UI typically reached via **SSH tunnel** to port `18789`.

This differs from “serverless only” habits: the official gateway story here is **a long-lived VM**, not Cloud Run, unless your team deliberately chooses another supported install (for example [Kubernetes](https://docs.openclaw.ai/install/kubernetes)) and documents it in `journal.md`.

**Detailed checklist, CS475 crosswalk, and links** live in **[`docs/phase-0-openclaw-gcp.md`](docs/phase-0-openclaw-gcp.md)**. **Optional GCE automation** (API enable, VM create, SSH tunnel, teardown, remote Docker install) lives in **[`gcp/README.md`](gcp/README.md)** (`gcp/phase0.env` from `phase0.env.example`).

### Tasks

1. **Prerequisites** — GCP project, billing, IAM (who can create VMs and SSH), chosen **zone** (upstream examples use `us-central1-a`), `gcloud` authenticated, SSH from operator laptops.
2. **Deploy** — Execute the upstream **GCP + Docker** flow: VM create → Docker install → repo clone or pinned image → compose / gateway start per [GCP install](https://docs.openclaw.ai/install/gcp) and [Docker VM runtime](https://docs.openclaw.ai/install/docker-vm-runtime). Pin **image digest or release tag** for anything student-facing.
3. **Networking** — Default upstream: gateway listens on **loopback on the VM**; operators use **`gcloud compute ssh … -L 18789:127.0.0.1:18789`**. If you expose the Control UI or gateway publicly, document firewall rules, auth tokens, and who may reach which ports (Slack / bridge in Phase 1 must match this design).
4. **Smoke test (operators)** — Prove Control UI or CLI dashboard path works after deploy (see checklist doc). Record command, tunnel if any, and outcome in `journal.md` (no secret values).
5. **Rollback** — Choose at least one: previous container image tag/digest, VM snapshot restore, or revision discipline. Write the exact commands or console steps in `journal.md`.

### Success criteria

- Another operator can redeploy or roll back using **`RUNBOOK.md` + [`docs/phase-0-openclaw-gcp.md`](docs/phase-0-openclaw-gcp.md)** and the linked OpenClaw docs.
- `journal.md` contains a **RUNBOOK Phase 0** entry with: timestamp, GCP project id, VM name and zone, machine type, OpenClaw **image digest or git SHA**, access method (e.g. SSH tunnel command pattern), smoke-test result, and rollback path reference.

**Closure:** After Phase 0 is green, recovery steps are in **[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)**. Historical narrative: [`archive/MANIFEST.md`](archive/MANIFEST.md) (`post-mortems/` in tarball).

---

## Phase 1: Slack app + happy path message

### Objective

**Verified** Slack traffic to the deployed OpenClaw gateway, and one **end-to-end** path works (e.g. app mention or DM → OpenClaw → reply in Slack).

**Checklist and transport choice:** **[`docs/phase-1-openclaw-slack.md`](docs/phase-1-openclaw-slack.md)**. Upstream bookmarks: **[`docs/openclaw-docs-index.md`](docs/openclaw-docs-index.md)**.

**Closure:** After Phase 1 is green, see **[`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)** for recovery. Historical narrative: [`archive/MANIFEST.md`](archive/MANIFEST.md) (`post-mortems/` in tarball).

### Recommended path (GCE VM): Socket Mode

For a **single gateway on GCE** (this runbook’s Phase 0), use OpenClaw’s default **[Socket Mode](https://docs.openclaw.ai/channels/slack.md)**: outbound WSS to Slack, **no public Request URL**, tokens via bot + app-level token. OpenClaw verifies the app-level connection; **Signing Secret is not used** on this path.

### Alternate path: HTTP Request URLs (deferred)

Not used for this project. Requires public HTTPS, **Signing Secret**, and inbound webhooks. See [OpenClaw Slack docs](https://docs.openclaw.ai/channels/slack.md) if you deliberately choose HTTP over Socket Mode on GCE.

### Tasks (Socket Mode — default)

1. **Plugin** — `openclaw plugins install @openclaw/slack` on the gateway host (or run [`gcp/vm/setup-slack-socket.sh`](gcp/vm/setup-slack-socket.sh)).
2. **Slack app** — Create/configure per upstream manifest (Socket Mode). Walkthrough: [`docs/SLACK_APP_WALKTHROUGH.md`](docs/SLACK_APP_WALKTHROUGH.md).
3. **OpenClaw config** — Golden script applies socket + channel policy patches; secrets **names only** in `journal.md`.
4. **Provider auth** — Export `GEMINI_API_KEY`; script sets `google/gemini-2.5-flash` (see [`docs/GEMINI_RATE_LIMITS.md`](docs/GEMINI_RATE_LIMITS.md)). Troubleshooting: [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).
5. **Happy path** — `@mention` in channel → reply in thread.

### Success criteria

- Valid tokens + config; gateway connects; one documented student-style `@mention` succeeds.
- `journal.md` lists Slack app identifiers, transport `socket`, and config **names only** for secrets (no secret values).

---

## Phase 2: Hardening (secrets, timeouts, abuse)

### Objective

Safe enough for a class workspace: secrets handled correctly, failures bounded, abuse mitigated.

### Tasks

1. **Secrets** — Slack signing secret, bot token, OpenClaw API keys: Secret Manager or equivalent; rotation notes; confirm logs and JSON errors do not echo secrets.
2. **Timeouts** — Outbound calls to OpenClaw and Slack APIs have explicit timeouts; document behavior on timeout (user-visible message vs retry).
3. **Retries and idempotency** — Use Slack `event_id` (or equivalent) to avoid duplicate processing when Slack retries.
4. **Abuse controls** — Rate limits, max payload sizes, allowed channels/DMs or workspace allowlist as appropriate for your course.
5. **Authorization** — Which Slack actors may trigger OpenClaw; document any admin-only surfaces.

### Success criteria

- No secrets in repository or client-visible error bodies.
- At least one failure-injection test documented (e.g. wrong signature, timeout) with expected outcome.

### Background reading

Security and MCP-adjacent course notes are in the archive bundle (`cs475-references/`); use as **supplementary** threat-modeling context, not as phase gates. See [`archive/MANIFEST.md`](archive/MANIFEST.md).

---

## Phase 3: Cost and operations

### Objective

Predictable cost and a short **ops** path when something breaks during a term.

### Tasks

1. **Cost** — Document Cloud Run (or GCE/GKE) min/max instances, concurrency, CPU/memory; model/API usage assumptions; Slack-related quotas if any.
2. **Monitoring** — Log queries or dashboards: Slack verification failures, OpenClaw 5xx, latency. Link to GCP console filters if helpful.
3. **Triage** — Short “if students see X, check Y” table (signatures, token expiry, OpenClaw revision drift, Slack incident status).
4. **Change management** — How to roll OpenClaw vs Slack app config; who approves production changes.
5. **Teardown** — End-of-term checklist: disable or uninstall app, revoke tokens, scale down or delete resources. For **GCE** sandboxes, nightly or between-session **VM stop** (compute off, disk still billed) and **start** are documented in [`gcp/README.md`](gcp/README.md#overnight-stop-and-start-the-vm).

### Success criteria

- On-call or course staff can answer “is it Slack, the bridge, or OpenClaw?” without reading the whole repo.

---

## Definition of done (this runbook)

| Phase | Done when |
|-------|-----------|
| 0 | OpenClaw gateway on GCP per [upstream GCP install](https://docs.openclaw.ai/install/gcp); smoke test and rollback documented in `journal.md` (see also `docs/phase-0-openclaw-gcp.md`). |
| 1 | Slack connected (Socket Mode or HTTP + signing); one happy-path student-style message documented. |
| 2 | Secrets, timeouts, and at least one abuse or failure scenario documented and tested. |
| 3 | Cost knobs and triage notes exist; teardown checklist exists. |

---

## Appendix: GCP HTTP smoke test (archived)

The Cloud Run HTTP smoke test (`src-cloud-run-smoke/` in the archive tarball) proved **local → container → Cloud Run** with JSON `/live` and `/` routes. It is **not** OpenClaw and **not** required for Phase 0 of this runbook.

Extract and commands: [`archive/MANIFEST.md`](./archive/MANIFEST.md).
