---
tags:
  - handoff
  - session-starter
  - deployment
date: '2026-06-25'
status: active
---

# 63 — Session Handoff (2026-06-25) — Fahad Demo Deployment Complete

> Load CONTEXT.md + LOG.md + this file at session start. Supersedes 62_Session_Handoff_2026-06-22.md.

---

## Current Repo State

- **Active branch:** `deploy/fahad-demo` (new — demo deployment state)
- **Master branch:** clean, untouched — all demo fixes are in deploy/fahad-demo only
- **Remote:** pushed to origin/deploy/fahad-demo
- **Alembic head:** `20260621_idempotency_constraints` (modified — uq_calls_tenant_audio_path removed)
- **Database:** PostgreSQL 16 running on Fahad's machine — constraint already dropped live

---

## What Was Done This Session (2026-06-24 to 2026-06-25)

Full end-to-end deployment on Fahad's Windows laptop (RTX 5060 Blackwell, 64GB RAM, Docker Desktop + WSL2).

Pipeline is **fully working**. All 7 stages complete. Score: 88%, Sentiment: POSITIVE, Resolution: RESOLVED.

See `64_Fahad_Demo_Deployment_Postmortem.md` for the full bug-by-bug breakdown.

---

## Code Changes in deploy/fahad-demo (vs master)

### 1. `backend/app/services/whisper_service.py`
**What changed:** PyTorch 2.7 changed `torch.load` default to `weights_only=True`. Pyannote/lightning_fabric explicitly passes `weights_only=True` which blocks omegaconf checkpoint loading.

**Fix:** Monkeypatch `torch.load` to force `weights_only=False` before any model loading. Also added `add_safe_globals` for omegaconf types as belt-and-suspenders.

```python
_orig_torch_load = torch.load
def _patched_torch_load(*args, **kwargs):
    kwargs['weights_only'] = False
    return _orig_torch_load(*args, **kwargs)
torch.load = _patched_torch_load
```

**Key detail:** Must use `kwargs['weights_only'] = False` (assignment), NOT `kwargs.setdefault(...)` — lightning_fabric explicitly passes the kwarg, so setdefault is a no-op.

---

### 2. `backend/Dockerfile.gpu.blackwell`
**What changed:**
- `ctranslate2>=4.4.0` → `ctranslate2==4.8.0` (pinned to exact working version)
- Removed `nvidia-cudnn-cu12==8.9.7.29` install and `LD_LIBRARY_PATH=/opt/cudnn8` — this was a failed cuDNN 8 workaround that is now obsolete

**Why:** CT2 4.4.0 was built against cuDNN 8. The Blackwell base image (cuda:12.8) ships cuDNN 9. CT2 looked for `libcudnn_ops_infer.so.8` which doesn't exist → SIGABRT. CT2 4.8.0 targets cuDNN 9 which is already present.

---

### 3. `backend/app/routers/calls.py`
**What changed:** Two bugs fixed.

**Bug 1 — MissingGreenlet:** `current_user.tenant_id` was accessed after `await db.rollback()` in the except block. After rollback, the ORM session expires all objects → accessing `tenant_id` triggers a lazy load → no greenlet context → crash.

**Fix:** Cache `tenant_id = current_user.tenant_id` as a local variable before any DB operations. Use the local variable in all except blocks.

**Bug 2 — TabError:** Notepad introduced mixed tabs/spaces when Fahad manually edited the file. Fixed by clean file replacement via docker cp.

---

### 4. `backend/app/routers/auth.py`
**What changed:** Added RLS bypass before the user lookup in the login endpoint.

**Why:** `users` table has RLS enabled with policy requiring `app.current_tenant` to be set or `app.platform_bypass = 'true'`. The login endpoint runs before any tenant context exists → RLS filters out ALL users → login always returns 401.

**Fix:**
```python
from sqlalchemy import select, text

await db.execute(text("SELECT set_config('app.platform_bypass', 'true', true)"))
result = await db.execute(select(User).where(User.email == body.email))
```

**Note:** This was a pre-existing bug that only surfaced after a full container restart cleared the DB session state.

---

### 5. `backend/alembic/versions/20260621_idempotency_constraints.py`
**What changed:** Removed the `uq_calls_tenant_audio_path` unique constraint creation.

**Why:** This constraint blocks demo re-uploads. The same audio file uploaded twice hits the constraint and returns 500 instead of processing. Removed for customer-facing demo.

**Live state:** Constraint was also dropped directly in the running PostgreSQL instance:
```sql
ALTER TABLE calls DROP CONSTRAINT IF EXISTS uq_calls_tenant_audio_path;
```

---

### 6. `infra/.env`
**What changed:** `GROQ_API_KEY` updated to new valid key.

**Why:** The old key (`gsk_q7plPMV6J...`) was revoked. Docker Compose loads `infra/.env` by default alongside `infra/.env.prod` — when both are present, `.env` values win. The key must be kept in sync in BOTH files.

**Critical:** `infra/.env` and `infra/.env.prod` MUST stay in sync. Stale key in `.env` overrides the correct key in `.env.prod` on every docker compose up.

---

## Infrastructure State (Fahad's Machine)

| Container | Image | Status | Notes |
|---|---|---|---|
| `cq_api` | infra-api | ✅ Running | FastAPI, hot-reload, auth RLS fix applied |
| `cq_worker_gpu` | infra-worker_cpu | ✅ Running | CT2 4.8.0, monkeypatch, CUDA 12.8 |
| `cq_worker_io` | infra-worker_io | ✅ Running | New Groq key active |
| `cq_postgres` | postgres:16-alpine | ✅ Running | dedup constraint dropped |
| `cq_redis` | redis:7.4.2-alpine | ✅ Running | |
| `cq_minio` | minio/minio:latest | ✅ Running | |
| `cq_nginx` | infra-nginx | ✅ Running | client_max_body_size 200m |
| `cq_flower` | mher/flower:2.0 | ✅ Running | |

**Public URL:** http://callquality.giize.com (Dynu DDNS → 100.118.221.10 via Tailscale)

---

## Remote Access Setup (Completed This Session)

- **Tailscale:** Adeen approved into Fahad's tailnet. Fahad's machine at `100.118.221.10`.
- **SSH:** WSL2 SSH server enabled. Windows portproxy forwards `0.0.0.0:22` → `172.18.100.217:22`.
- **Zed:** Connected via `zed ssh://fahad@100.118.221.10/mnt/c/Users/fahad/call-qualtiy/call-quality-analytics`
- **Docker:** Requires `sudo docker` from WSL2 (Docker Desktop WSL integration enabled)

**WSL2 SSH does not persist across WSL restarts.** Fahad must run `sudo service ssh start` each session.

**Windows portproxy does persist** (survives reboots) but WSL2 IP may change — if SSH stops working after a reboot, Fahad must re-run:
```powershell
netsh interface portproxy delete v4tov4 listenport=22 listenaddress=0.0.0.0
netsh interface portproxy add v4tov4 listenport=22 listenaddress=0.0.0.0 connectport=22 connectaddress=<new WSL2 IP>
```
Get WSL2 IP with: `ip addr show eth0 | grep "inet "` inside WSL2.

---

## Known Issues (Post-Demo Fixes Required Before First Customer)

| Issue | Severity | File | Notes |
|---|---|---|---|
| dedup constraint removed | HIGH | alembic migration + live DB | Must be re-evaluated — without it, same file can create multiple call records |
| auth.py RLS bypass is broad | MEDIUM | app/routers/auth.py | `platform_bypass=true` for entire login flow. Should scope to just the user lookup. |
| infra/.env not gitignored | HIGH | infra/.env | Contains live secrets. Verify .gitignore covers it. |
| reset_and_seed.py hardcodes localhost | LOW | reset_and_seed.py | Replace `@cq_postgres:` with `@localhost:` — must be run with DATABASE_URL override |
| SSH not persistent | LOW | WSL2 | `sudo service ssh start` needed each session |
| Groq key in both .env files | MEDIUM | infra/.env + infra/.env.prod | Both must stay in sync manually |
| nginx DNS cache stale after restart | LOW | docker networking | `docker exec cq_nginx nginx -s reload` required after any container IP change |

---

## Deployment Survival Guide (What to Do After Restart)

If Fahad's machine reboots or Docker restarts:

```bash
# In WSL2
sudo service ssh start
cd /mnt/c/Users/fahad/call-qualtiy/call-quality-analytics
sudo docker compose -f infra/docker-compose.app.yml --env-file infra/.env.prod up -d
sudo docker restart cq_worker_gpu
sudo docker exec cq_nginx nginx -s reload
```

Wait ~30 seconds then verify:
```bash
sudo docker ps --format "table {{.Names}}\t{{.Status}}"
```

If login fails → run nginx reload again (stale DNS cache).

If Groq 401 → check `grep GROQ infra/.env` — update if stale.

---

## Seeded Accounts (Active)

| Email | Password | Role |
|---|---|---|
| admin@callquality.demo | admin1234 | TENANT_ADMIN |
| supervisor@callquality.demo | supervisor1234 | SUPERVISOR |
| viewer@callquality.demo | viewer1234 | VIEWER |
| platform@callquality.internal | platform1234 | PLATFORM_ADMIN |

**Note:** Passwords are bcrypt hashed in DB. If login fails after a fresh seed run, the seed script hardcodes `@localhost:` in the DATABASE_URL — it will fail unless run with URL override. Reset individual user passwords with:
```bash
sudo docker exec -it cq_api python -c "
import bcrypt, psycopg2
pw = bcrypt.hashpw(b'admin1234', bcrypt.gensalt(rounds=12)).decode()
conn = psycopg2.connect('postgresql://callquality:<password>@cq_postgres:5432/callquality')
cur = conn.cursor()
cur.execute(\"UPDATE users SET password_hash = %s WHERE email = 'admin@callquality.demo'\", (pw,))
conn.commit()
"
```

---

## Tooling Added This Session

- **LogClear Gemini Gem:** Preprocesses raw Docker/terminal logs into Claude-optimized format. Strips NVIDIA boilerplate, collapses identical errors, truncates JWT tokens, removes ANSI codes. Use before pasting logs into any LLM session.

---

## Next Session Starting Point

1. Master branch is clean — no deployment fixes merged in
2. `deploy/fahad-demo` branch is the live deployment state
3. ROI reporting module is next on roadmap
4. Agentic AI assistant (NL query over PostgreSQL) is after ROI
5. Post-demo: evaluate OVHcloud Beauharnois + RunPod GPU for production
6. OpenRouter replaces Groq as primary LLM at first paying customer (not yet implemented)

---

## Vault Reference

| File | Purpose |
|---|---|
| CONTEXT.md | Full architecture |
| INVARIANTS.md | Compact rules |
| 63_Session_Handoff_2026-06-25.md | This file |
| 64_Fahad_Demo_Deployment_Postmortem.md | Full bug timeline with decisions |
| KNOWN_ISSUES.md | Update after reading this |
| ROADMAP.md | Post-demo phases |
