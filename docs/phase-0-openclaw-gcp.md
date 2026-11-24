# Phase 0 implementation: OpenClaw on GCP (vendor path)

This document expands **[`RUNBOOK.md`](../RUNBOOK.md) § Phase 0**. If anything here disagrees with upstream, **follow upstream**.

## Canonical upstream

| Resource | URL |
|----------|-----|
| **GCP install (primary for this repo’s runbook)** | [OpenClaw on GCP](https://docs.openclaw.ai/install/gcp) — Compute Engine VM + Docker, persistent `~/.openclaw`, Control UI via SSH tunnel by default |
| Docker (generic / pre-built images) | [Docker](https://docs.openclaw.ai/install/docker) — e.g. `ghcr.io/openclaw/openclaw` tags |
| Docker VM runtime (bake, build, updates) | [Docker VM runtime](https://docs.openclaw.ai/install/docker-vm-runtime) |
| Kubernetes | [Kubernetes](https://docs.openclaw.ai/install/kubernetes) |
| Security for network exposure | [Gateway security](https://docs.openclaw.ai/gateway/security) |
| Doc index (upstream) | [llms.txt](https://docs.openclaw.ai/llms.txt) |
| Doc index (this repo) | [`openclaw-docs-index.md`](./openclaw-docs-index.md) — curated bookmarks by runbook phase |

Official GCP guide summary: **not Cloud Run** for the default gateway path—it is a **persistent VM** with Docker, host-mounted config, and **recommended access via SSH port forward** to the Control UI on port `18789` (unless you deliberately expose ports and firewall).

## What this repo is not doing in Phase 0

- **Cloud Run HTTP smoke test** — Archived; see [`archive/MANIFEST.md`](../archive/MANIFEST.md). It does **not** replace the OpenClaw gateway.
- **Slack** — Channel wiring is **RUNBOOK Phase 1**; upstream channel docs live under [Channels](https://docs.openclaw.ai/channels).

## CS475 materials (archived)

Course references that assumed a **Cloud Run + narrow HTTP route** lab progression are in the archive bundle (`cs475-references/`, `lab-track/`). **Phase 0 here follows OpenClaw’s official GCP path (GCE + Docker)** instead. That is intentional for the team runbook.

| CS475 theme | Where it lands for this Phase 0 |
|-------------|----------------------------------|
| **G01.1** — scripted steps, env-based config, cost-aware teardown | Keep commands copy-pasteable; standardize **one** zone/region; document **VM stop / delete** or compose `down` so sandboxes do not leak cost. |
| **G04.1** — Cloud Run, `/live` vs `/healthz`, MCP HTTP | Applies to the **archived** Cloud Run smoke test only, **not** to the OpenClaw gateway on GCE. |
| **G05.1** — injection, agency, validation | Full **red-team prompt suites** belong in **RUNBOOK Phase 2** once Slack and tools are live; for Phase 0 still apply **network exposure** discipline: follow [Gateway security](https://docs.openclaw.ai/gateway/security), avoid public Control UI without firewall + auth, treat any exposed port as untrusted input. |
| **cs475-src** — secrets, credential lifecycle, normalized errors | Already aligned: no secrets in git; prefer **Secret Manager** or host-only secrets for production-ish VMs; note **OAuth refresh / expiry** behavior lives in mounted `auth-profiles` per upstream—plan who rotates what before the term. |
| **Lectures (`04`/`05`)** — MCP is not the security layer; least privilege | Use **dedicated service accounts** with narrow roles for automation (OpenClaw’s GCP guide includes an example); enforce **auth on the gateway**, not “security by SSH only” if you ever widen bind addresses. |

For the full lecture table mapping RUNBOOK phases to themes, extract `cs475-references/cs475-lecture-reference-for-openclaw-gcp.md` from [`archive/MANIFEST.md`](../archive/MANIFEST.md).

## Repo automation (GCE only)

This repository includes **optional** bash helpers under [`gcp/`](../gcp/): enable Compute API, create/**start**/stop/delete the Debian VM, open an SSH tunnel to the default gateway port, and run a remote Docker install script. They read **`gcp/phase0.env`** (copy from `gcp/phase0.env.example`). See [`gcp/README.md`](../gcp/README.md). **`gcp/vm/patch-compose-allow-unconfigured.sh`** aligns stock `docker-compose.yml` with the upstream GCP bootstrap by inserting `gateway … --allow-unconfigured` until **`gateway.mode`** exists—otherwise the gateway exits (*“missing gateway.mode”*). Set mode with upstream onboarding (e.g. **`gcp/vm/onboard-noninteractive-local.sh`** from the laptop via `vm-exec`, then **remove** the flag with **`gcp/vm/remove-compose-allow-unconfigured.sh`** and recreate the gateway container; see [`gcp/README.md`](../gcp/README.md) **Harden**).

**OpenClaw clone, compose, and tokens** remain on the official install doc—run those steps **on the VM** after Docker is ready.

### Future refactor (when complexity warrants it)

The current `gcp/` helpers are **bash + `gcloud` + SSH**: easy to adopt and enough for a single sandbox or small team. They are only **lightly idempotent** (for example, VM create skips if the instance name already exists, but they do not reconcile drift if a VM’s machine type, disk, or IAM should change).

If operators later need **declarative GCP resources**, **plan/apply review**, **remote state**, or **CI gates** on infra changes, consider refactoring along a common split:

- **OpenTofu** (or Terraform) for **provisioning**: Compute Engine instance, boot disk, optional static IP, service accounts, IAM bindings, firewall rules, labels/tags for inventory.
- **Ansible** (after SSH or OS Login works) for **guest configuration**: convergent package/Docker setup, templated files, and thin wrappers around upstream OpenClaw commands—still **without** duplicating vendor install logic in HCL.

Upstream OpenClaw steps stay authoritative; automation only **orchestrates** them. Until that refactor, keep using [`gcp/README.md`](../gcp/README.md) and treat this subsection as a **deferred** architecture note.

## Operator checklist (GCE + Docker path)

Complete in order; paste evidence into [`journal.md`](../journal.md) under **RUNBOOK Phase 0 — OpenClaw on GCP**.

1. **GCP project** — Project id, billing enabled, Compute Engine API enabled (`gcloud services enable compute.googleapis.com`). Optional: run [`gcp/scripts/enable-apis.sh`](../gcp/scripts/enable-apis.sh) after configuring [`gcp/phase0.env`](../gcp/phase0.env).
2. **VM** — Name, zone, machine type (upstream recommends **e2-small** minimum for Docker builds; **e2-micro** often OOMs). Boot disk size and OS (e.g. Debian 12). Optional: [`gcp/scripts/create-vm.sh`](../gcp/scripts/create-vm.sh).
3. **SSH** — Confirm `gcloud compute ssh` works; note if OS Login is required. Helpers: [`gcp/scripts/vm-exec.sh`](../gcp/scripts/vm-exec.sh), [`gcp/scripts/ssh-tunnel.sh`](../gcp/scripts/ssh-tunnel.sh).
4. **Docker on VM** — `docker` and `docker compose` versions recorded. Optional: [`gcp/vm/install-docker-debian.sh`](../gcp/vm/install-docker-debian.sh) via [`gcp/README.md`](../gcp/README.md).
5. **OpenClaw source or image** — Either clone `https://github.com/openclaw/openclaw.git` per upstream or pin `OPENCLAW_IMAGE` to a specific **digest or version tag** (not floating `latest` in production).
6. **Host persistence** — Directories for config/workspace mounted as in upstream (`~/.openclaw`, workspace path).
7. **Secrets** — `.env` and keyring password live **only** on the host or in Secret Manager; **never** commit them. Document **which** secret names you use in `journal.md` (values redacted).
8. **Gateway bind / ports** — Default upstream pattern binds Control UI to loopback on the VM and uses **SSH tunnel** from laptop. If you change to public exposure, document firewall rules + auth and link your threat review.
9. **Launch** — `docker compose` (or upstream-equivalent) up; container restart policy noted. If the stock compose command lacks `--allow-unconfigured` and the gateway exits with “Missing config…”, use [`gcp/vm/patch-compose-allow-unconfigured.sh`](../gcp/vm/patch-compose-allow-unconfigured.sh) to match the upstream GCP bootstrap. Before **removing** that flag, ensure **`gateway.mode`** is set (blocked otherwise); use upstream onboarding or [`gcp/vm/onboard-noninteractive-local.sh`](../gcp/vm/onboard-noninteractive-local.sh) per [`gcp/README.md`](../gcp/README.md) **Harden**, then [`gcp/vm/remove-compose-allow-unconfigured.sh`](../gcp/vm/remove-compose-allow-unconfigured.sh) and recreate the gateway container.
10. **Smoke test** — At least one of:
    - Browser to Control UI through tunnel with successful auth; or
    - `docker compose run --rm openclaw-cli dashboard --no-open` (or current upstream equivalent) showing expected URL; or
    - Another **documented** health path from upstream you choose as team standard.
11. **Negative check (CS475-style “known failure”)** — One deliberate bad path with expected outcome, e.g. tunnel not started (connection refused), wrong gateway token (401 / UI error), or wrong SSH user—record in `journal.md` so the next operator can tell **misconfig** from **OpenClaw bug**.
12. **Rollback** — Written steps: e.g. stop containers, pin previous image tag, restore VM snapshot, or `gcloud compute instances` stop + disk rollback—pick what your team actually uses.
13. **Teardown / cost (G01)** — For class sandboxes: document how to **stop or delete** the VM (or scale to zero if you introduce autoschedule) and remove unused static IPs so billing does not drift. For **overnight or between-session** stops (compute off, disk kept), follow [**Overnight: stop and start the VM**](../gcp/README.md#overnight-stop-and-start-the-vm) in [`gcp/README.md`](../gcp/README.md) (`./scripts/stop-vm.sh`, `./scripts/start-vm.sh`). For **destructive** teardown, optional: [`gcp/scripts/delete-vm.sh`](../gcp/scripts/delete-vm.sh).

## Artifacts to record in `journal.md`

| Field | Example (no secrets) |
|-------|----------------------|
| Date / timezone | |
| GCP project id | |
| VM name, zone, machine type | |
| OpenClaw image digest or git SHA | |
| Gateway bind and port | `lan` / `18789` per your `.env` |
| Access pattern | SSH tunnel command used |
| Smoke test outcome | Pass / fail + one-line evidence |
| Rollback tested? | Y/N; which procedure |
| Negative check run | Which scenario; expected vs actual |
| Teardown / cleanup | Command or console path used when sandbox ends |

## Rollback (templates)

Pick and document one primary approach:

**A. Docker image pin** — Keep previous `OPENCLAW_IMAGE` tag/digest in a private note; `docker compose pull` / `up` to revert.

**B. VM disk snapshot** — Snapshot before upgrade; restore procedure linked from GCP console or `gcloud` commands.

**C. GCE machine type / resize** — Upstream documents stopping VM and `set-machine-type` when OOM; include that under reliability, not only rollback.

## Handoff to Phase 1 (Slack)

When Phase 0 is green:

- Gateway reachable by operators (and by any **bridge** host you will use for Slack) per your networking choice.
- Proceed to **`RUNBOOK.md` Phase 1** via [`phase-1-openclaw-slack.md`](./phase-1-openclaw-slack.md). **Default for this VM:** [Slack Socket Mode](https://docs.openclaw.ai/channels/slack.md) (no public Request URL). Bookmarks: [`openclaw-docs-index.md`](./openclaw-docs-index.md).

**Phase 0 closure:** Recovery — [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md). Historical narrative — [`archive/MANIFEST.md`](../archive/MANIFEST.md).
