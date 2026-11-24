# Phase 0 — GCP helpers (OpenClaw GCE path)

These scripts automate **only the Google Compute Engine shell** for [OpenClaw on GCP](https://docs.openclaw.ai/install/gcp): APIs, VM create/stop/delete, SSH tunnel, and a one-shot Docker install on Debian. They deploy infrastructure for the **CS112 personal agent via Slack** — see [`../PRODUCT.md`](../PRODUCT.md).

**OpenClaw-specific steps** (clone repo, `.env`, `docker-compose.yml`, gateway token, Control UI auth, onboarding) still follow **upstream**—do not duplicate them here; run them on the VM after Docker is installed.

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud`) authenticated (`gcloud auth login`).
- Billing enabled on your GCP project.
- Permissions to enable APIs, create VMs, and use `gcloud compute ssh`.

## One-time local setup

```bash
cd experiments/openclaw-google/gcp
cp phase0.env.example phase0.env
# Edit phase0.env: set GCP_PROJECT_ID and any non-default zone/VM name.
chmod +x scripts/*.sh vm/*.sh
```

`phase0.env` is gitignored; never commit secrets.

## Your next steps (after the gateway container is up)

1. **Control UI** — From `experiments/openclaw-google/gcp`, run `./scripts/ssh-tunnel.sh` (blocks until Ctrl+C). Open `http://127.0.0.1:${LOCAL_TUNNEL_PORT}/` (default `18789` matches [`phase0.env.example`](./phase0.env.example)). On the VM, read `~/openclaw/.env` for the gateway token (e.g. `OPENCLAW_GATEWAY_TOKEN` per upstream); paste it in the browser locally. **Do not** commit `.env` or tokens.

2. **Full setup** — Finish onboarding per upstream: [OpenClaw on GCP](https://docs.openclaw.ai/install/gcp), [`openclaw` CLI setup](https://docs.openclaw.ai/cli/setup.md), [gateway configuration](https://docs.openclaw.ai/gateway/configuration.md) (including `gateway.mode` as documented there), [authentication](https://docs.openclaw.ai/gateway/authentication.md), and [gateway security](https://docs.openclaw.ai/gateway/security) for exposure and auth expectations.

3. **Harden** — Before removing `--allow-unconfigured`, the gateway must have **`gateway.mode`** set (otherwise the container exits and logs *“Gateway start blocked… missing gateway.mode”*). If you only used the bootstrap patch and never onboarded, run non-interactive local onboarding once (token must exist in `~/openclaw/.env` as `OPENCLAW_GATEWAY_TOKEN`):

   ```bash
   # From your laptop (repo), after gateway is healthy with --allow-unconfigured:
   ./scripts/vm-exec.sh bash -s < vm/onboard-noninteractive-local.sh
   ```

   Then remove `--allow-unconfigured` from `~/openclaw/docker-compose.yml`: run [`vm/remove-compose-allow-unconfigured.sh`](./vm/remove-compose-allow-unconfigured.sh) on the VM (e.g. `./scripts/vm-exec.sh bash -s < vm/remove-compose-allow-unconfigured.sh`), then recreate:

   `sudo docker compose -f "$HOME/openclaw/docker-compose.yml" --project-directory "$HOME/openclaw" up -d --no-build --force-recreate`

   Smoke on the VM: `curl -sS -i http://127.0.0.1:18789/healthz` → **HTTP 200** with `{"ok":true,"status":"live"}`.

   **Recovery:** If the gateway crash-loops after removing the flag, re-apply [`vm/patch-compose-allow-unconfigured.sh`](./vm/patch-compose-allow-unconfigured.sh), recreate, run onboarding above, then remove the flag again.

   Tighten exposure as needed: IAP SSH ([`GCE_USE_IAP_TUNNEL`](./phase0.env.example)), VPC firewall rules, and gateway bind address per [Gateway security](https://docs.openclaw.ai/gateway/security)—do not rely on `--allow-unconfigured` once students or shared workspaces are in scope.

## Suggested order

| Step | Command | Notes |
|------|---------|--------|
| 1 | `./scripts/enable-apis.sh` | Enables Compute Engine API. |
| 2 | `./scripts/create-vm.sh` | Skips if the VM already exists. |
| 3 | `./scripts/describe-vm.sh` | Confirms status / external IP (if any). |
| 4 | Install Docker on the VM | See below. |
| 5 | On the VM | Shallow clone to `~/openclaw`, `mkdir -p ~/.openclaw ~/.openclaw/workspace`, create `~/openclaw/.env` per [OpenClaw GCP](https://docs.openclaw.ai/install/gcp) (secrets **only** on the VM). If the gateway container restarts with `Missing config…`, apply [`vm/patch-compose-allow-unconfigured.sh`](./vm/patch-compose-allow-unconfigured.sh) (e.g. `./scripts/vm-exec.sh bash -s < vm/patch-compose-allow-unconfigured.sh`), then `sudo docker compose -f "$HOME/openclaw/docker-compose.yml" --project-directory "$HOME/openclaw" up -d --no-build --force-recreate`. After real setup, use [`vm/remove-compose-allow-unconfigured.sh`](./vm/remove-compose-allow-unconfigured.sh) and recreate the container (see **Your next steps** above). |
| 6 | Tunnel (separate terminal) | `./scripts/ssh-tunnel.sh` then open `http://127.0.0.1:${LOCAL_TUNNEL_PORT}/` when the gateway is healthy. |
| 7 | Journal | Record outputs under **RUNBOOK Phase 0** in [`../journal.md`](../journal.md). |

## Phase 1 — Slack (after Phase 0 is green)

1. Create the Slack app: [`../docs/SLACK_APP_WALKTHROUGH.md`](../docs/SLACK_APP_WALKTHROUGH.md) (manifest: [`vm/slack-app-manifest.socket.minimal.json`](./vm/slack-app-manifest.socket.minimal.json); short checklist: [`vm/SLACK_APP_SETUP.md`](./vm/SLACK_APP_SETUP.md)).
2. Export `SLACK_APP_TOKEN`, `SLACK_BOT_TOKEN`, and **`GEMINI_API_KEY`** (recommended), then run [`vm/setup-slack-socket.sh`](./vm/setup-slack-socket.sh). The script applies socket + channel policy patches, sets model stack **3.5-flash → 2.5-flash fallback** ([`vm/model-failover.patch.json5`](./vm/model-failover.patch.json5), [`../docs/GEMINI_RATE_LIMITS.md`](../docs/GEMINI_RATE_LIMITS.md)), and restarts the gateway. API smoke: [`vm/smoke-gemini-chat-models.sh`](./vm/smoke-gemini-chat-models.sh). Prep without tokens: `./vm/setup-slack-socket.sh --prep-only`.

**Env vars (local shell, never commit):** `SLACK_APP_TOKEN`, `SLACK_BOT_TOKEN`, `GEMINI_API_KEY` (optional `GOOGLE_API_KEY`). Troubleshooting: [`../docs/TROUBLESHOOTING.md`](../docs/TROUBLESHOOTING.md).

**Note:** `@openclaw/slack` requires OpenClaw **≥ 2026.5.12**; if plugin install fails on an older pinned image, pull `ghcr.io/openclaw/openclaw:latest` and update `OPENCLAW_IMAGE` in VM `~/openclaw/.env` before retrying.

Further context: [`../docs/phase-1-openclaw-slack.md`](../docs/phase-1-openclaw-slack.md).

## Course materials (lecture PDFs on VM)

After Slack + persona are working:

1. Generate deploy PDFs locally: `cd vm/course-materials && ./prep-pdfs-for-openclaw.sh` (requires `pdf-raw/`; see [`vm/course-materials/README.md`](./vm/course-materials/README.md)).
2. From `gcp/`: [`vm/setup-course-materials.sh`](./vm/setup-course-materials.sh) — uploads `cs112-*.pdf` to `~/.openclaw/workspace/course/`, applies [`vm/course-tools.patch.json5`](./vm/course-tools.patch.json5) (`read` + `pdf` tools), deploys `TOOLS.md`, restarts gateway.
3. [`vm/setup-persona.sh`](./vm/setup-persona.sh) — picks up `SOUL.md` / `AGENTS.md` / `TOOLS.md` if changed.

Demo prompts: [`../docs/PERSONAL_AGENT.md`](../docs/PERSONAL_AGENT.md) (D1 grounded, D6 quiz from slides).

### Install Docker on the VM (from your laptop)

From `gcp/`:

```bash
./scripts/vm-exec.sh bash -s < vm/install-docker-debian.sh
```

Then SSH once more (or `newgrp docker`) so the `docker` group applies, per script output.

### Remote one-liners

```bash
./scripts/vm-exec.sh bash -lc 'uname -a'
./scripts/vm-exec.sh sudo docker images
./scripts/vm-exec.sh sudo docker pull ghcr.io/openclaw/openclaw:latest
```

Use `sudo docker …` until you have opened a **new** SSH session after `install-docker-debian.sh` (so the `docker` group applies without sudo).

Everything after the script name is forwarded to `ssh` on the VM (after `gcloud compute ssh … --`).

## Overnight: stop and start the VM

Use this when you want to **avoid compute charges** while keeping the boot disk and OpenClaw files on the VM.

### Stop (safe for “tonight”)

1. **Close the SSH tunnel** if it is running (Ctrl+C in the terminal where `./scripts/ssh-tunnel.sh` is attached).
2. **Optional — stop containers first** — In an **interactive** `gcloud compute ssh` session on the VM, from `~/openclaw` run `docker compose … down` (or `sudo docker compose …` if you are not in the `docker` group yet). That stops the gateway stack before the guest shuts down. Skipping this is usually fine: `gcloud compute instances stop` asks the guest for an orderly shutdown (ACPI), and persisted volumes under `~/.openclaw` remain on disk.
3. **From your laptop**, with `gcp/phase0.env` configured:

```bash
cd experiments/openclaw-google/gcp
./scripts/stop-vm.sh
```

**Billing:** Stopping the VM turns off **vCPU/RAM** billing; you still pay for the **boot disk** (and any **static external IP** if the instance used one while stopped—see GCP pricing). Use [`delete-vm.sh`](./scripts/delete-vm.sh) only when you intend to destroy the sandbox.

**Heads-up:** Running `docker compose down` via **`./scripts/vm-exec.sh`** in a non-interactive SSH session can fail if `sudo` needs a password or the remote command is parsed oddly; prefer an interactive SSH session for compose if you want that extra step.

### Start (next day)

After the instance is `TERMINATED`, start it again from the same directory:

```bash
./scripts/start-vm.sh
```

Then SSH or open the tunnel as before (`./scripts/ssh-tunnel.sh`) and bring the stack up on the VM if it does not auto-start (per your compose restart policy).

## Teardown (destructive / end of sandbox)

```bash
./scripts/stop-vm.sh    # stop compute; disk still billed
./scripts/delete-vm.sh # destructive; prompts for "yes"
```

Review static IPs and disks in the GCP console if you created extras.

## IAP SSH

If your org requires IAP tunneling for SSH, set in `phase0.env`:

```bash
export GCE_USE_IAP_TUNNEL="true"
```

## Troubleshooting

- **SSH refused** right after create: wait 1–2 minutes (key propagation), retry.
- **`gcloud` project**: every command passes `--project="$GCP_PROJECT_ID"` from `phase0.env`; your active `gcloud` config is not modified by these scripts.

## See also

- [`../docs/phase-0-openclaw-gcp.md`](../docs/phase-0-openclaw-gcp.md) — full checklist and CS475 crosswalk (including **Future refactor**: OpenTofu + Ansible when plan/apply and deeper idempotency matter more than minimal tooling).
- [`../RUNBOOK.md`](../RUNBOOK.md) — operator phases 0–3.
