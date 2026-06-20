---
tags: [handoff, session-starter]
date: 2026-06-19
status: active — paste this + INVARIANTS.md at next session start
---

# 44 — Session Handoff (2026-06-19)

> Workflow: Claude Code = architect/auditor/prompt writer. Codex = backend. Antigravity = frontend.
> See INVARIANTS.md for all rules. See CONTEXT.md for full architecture.

---

## Current State — v1.7

- Architecture: single Azure B4ms (4 vCPU, 16GB, ~$0.19/hr), all 9 services self-contained, CPU WhisperX
- Alembic head: `20260526_platform_rls_bypass` (8 migrations)
- Platform admin: 5 pages live (overview, tenants, health, usage, call monitor)
- Multi-tenancy: triple-layer RLS, Demo Tenant + Acme Corp verified isolated
- Design system: Waaqi GRC tokens (#00a99d primary, #0f1924 sidebar)
- All predeployment code + infra files committed and pushed to GitHub master
- `batch_agent/` deleted (superseded by MinIO webhook model)
- `infra/.env.example` committed — template for Azure VM setup
- graphify full semantic update complete: 1,061 nodes, 2,320 edges, 63 named communities (OpenRouter DeepSeek v3)
- Obsidian MCP vault path corrected in `~/.claude.json` → `/home/malikadeen/Documents/second-brain/cqa-vault`
- `openrouter-ds` custom graphify provider registered globally (`~/.graphify/providers.json`)

---

## What Was Done This Session (2026-06-19)

Full predeployment checklist completed:

**Code fixes:**
- `20260526_platform_rls_bypass.py` — migration that modifies existing tenant_isolation policies to add `OR current_setting('app.platform_bypass', true) = 'true'` clause, with proper downgrade. Remote version preferred over local (uses `= 'true'` matching CLAUDE.md invariant, not `= 'on'`)
- `database.py` — SET LOCAL f-string replaced with `set_config()` parameterised call
- `minio_event.py` — same SET LOCAL fix
- `tasks.py` — `notify_websocket` Redis URL now `os.environ["REDIS_URL"]` (no fallback default)

**Infrastructure files created:**
- `backend/Dockerfile.cpu` — python:3.11-slim, CPU torch, whisperx, pyannote (no CUDA)
- `frontend/Dockerfile` — multi-stage Vite build → nginx:alpine
- `infra/nginx.conf` — SPA serve + /api proxy + /ws proxy + gzip + X-Forwarded-Proto
- `infra/docker-compose.azure.yml` — 9 services, no GPU reservation, WHISPER_DEVICE=cpu, Redis AOF, Flower auth+loopback, all ports 127.0.0.1

**Git:** Rebased on remote (resolved 4 conflicts: CLAUDE.md, platform_bypass migration, frontend/Dockerfile, nginx.conf). Pushed to master.

---

## NEXT — Azure VM Provision + Deploy

Everything is code-complete. Only infrastructure steps remain:

### Step 1 — Provision (run locally, ~3 min)
```bash
az login  # confirm logged in first: az account show
az group create --name callquality-rg --location eastus
az vm create \
  --resource-group callquality-rg --name callquality-prod \
  --image Ubuntu2204 --size Standard_B4ms --location eastus \
  --admin-username azureuser --generate-ssh-keys --public-ip-sku Standard
az vm open-port --resource-group callquality-rg --name callquality-prod --port 80 --priority 1000
az vm open-port --resource-group callquality-rg --name callquality-prod --port 22 --priority 1001
```

### Step 2 — Configure VM (SSH)
```bash
ssh azureuser@<VM_IP>
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker azureuser
# log out + back in
```

### Step 3 — Deploy (10-15 min first build)
```bash
git clone https://github.com/Malik-Adeen/call-quality-analytics.git
cd call-quality-analytics && nano infra/.env && chmod 600 infra/.env
docker compose -f infra/docker-compose.azure.yml up -d --build
```
Set `WHISPER_MODEL=small` in .env for demo phase (30s vs 90-120s for large-v2).

### Step 4 — Migrate + Seed
```bash
docker compose -f infra/docker-compose.azure.yml exec api alembic upgrade head
pip3 install psycopg2-binary bcrypt python-dotenv
python3 scripts/reset_and_seed.py
```

### Step 5 — Verify
```bash
curl http://<VM_IP>/api/health                # {"success":true,"data":{"status":"ok"}}
ss -tlnp | grep -E '5432|6379|9000|8000'     # all must show 127.0.0.1 not 0.0.0.0
```
Full checklist: [[11_Azure_Deployment]] Task 6.

---

## Deferred (non-blocking)

- Playwright in worker_io (~500MB waste) — Phase 2 Dockerfile.worker split
- MinIO presigned URL double-prefix (audio playback broken) — fix when re-enabling audio
- Azure Key Vault migration for secrets — before first paying tenant
- PostgreSQL daily backup cron to Azure Blob — before first paying tenant
- HTTPS (Let's Encrypt + certbot) — before production SaaS

---

## Startup (local dev — unchanged)

```powershell
cd N:\projects\call-quality-analytics\infra && docker compose up -d
cd N:\projects\call-quality-analytics\frontend && npm run dev
```

Login 1: `admin@callquality.demo / admin1234`  (Demo Tenant — seeded calls)
Login 2: `admin@acme.demo / acme1234`           (Acme Corp — 0 calls)

---

## Audit Checklist (every Codex/Antigravity file)

- [ ] Zero code comments
- [ ] `minio_audio_path` never `audio_path`
- [ ] `cq-minio:9000` hyphens
- [ ] `extract_agent_identity` BEFORE `redact_pii`
- [ ] Talk balance: `1 - 2 * abs(agent_ratio - 0.5)`
- [ ] Score: stored 0–10, displayed ×10 as %
- [ ] JWT in sessionStorage never localStorage
- [ ] Groq: `llama-3.3-70b-versatile`
- [ ] `set_config()` not f-string for RLS tenant setting
- [ ] `os.environ["REDIS_URL"]` no fallback default
- [ ] Waaqi GRC design: #00a99d primary, #0f1924 sidebar, Inter + JetBrains Mono
