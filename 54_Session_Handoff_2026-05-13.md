---
tags: [handoff, session-starter]
date: 2026-05-13
status: active
---

# 54 — Session Handoff (2026-05-13)

> Paste CONTEXT.md + this file at the start of any new session.

---

## What Was Done This Session

### Batch Test (Demo Tenant — Phase 1)
- PC had crashed mid-test (thermal shutdown during WhisperX inference) in prior session
- TDR fix confirmed intact (TdrDelay=TdrDdiDelay=0x12c)
- Docker stack brought back up — all 9 containers running (including cq_minio_init one-shot)
- Cleared 4 stuck calls from crash: `UPDATE calls SET status='failed' WHERE status IN ('processing','pending')` → UPDATE 4
- Redis queues already empty from crash — DEL returned 0 (expected)
- BatchAgent checksums cleared: `rm -f /data/*.json` + `docker restart cq_batch_agent`
- Triggered 5-file Phase 1 batch upload to Demo Tenant via move-trick (temp_stage → demo_tenant)
- Pipeline confirmed running: WhisperX active, GPU thermals 45-56°C peak, 122W peak (well under 80°C / 150W limits)
- VRAM peak 3.5GB during inference (normal for large-v2)
- 4 failed calls confirmed as pre-crash orphans (created_at 07:48) — not new failures
- Phase 1 batch test left running but not fully verified (session switched before all 5 completed)
- Phase 2 (split-tenant test: Demo→sarah+marcus, BPO→aisha+david+priya) NOT yet run

### Manager PC Deployment Decision
- Deploying to manager's PC tonight (local Docker, not Azure)
- Manager PC specs: RTX 5060 8GB VRAM (Blackwell, sm_120), 64GB RAM, Ryzen 7 CPU
- **Critical finding:** RTX 5060 is Blackwell (sm_120) — INCOMPATIBLE with current stack
  - Current: `nvidia/cuda:12.1.0-cudnn8` base + `torch==2.2.0+cu121`
  - PyTorch 2.2.0 has no compiled kernels for sm_120, will crash or fall back to CPU
  - Required: CUDA 12.8 base + `torch==2.7.0+cu128`
- **Decision:** Edit Dockerfile.gpu directly on manager's PC after `git clone` — NOT committed to git
- No git changes needed on Adeen's machine

---

## What To Do Next

### Tonight — Manager PC Deployment

**Step 1 — Prerequisites on manager's PC:**
- Docker Desktop + WSL2 installed and running
- NVIDIA driver 575+ (required for CUDA 12.8 / RTX 5060)
- Git installed
- ~15GB disk free (models download on first run)
- Good internet connection (WhisperX large-v2 + Pyannote = ~3.5GB download on first run)

**Step 2 — Clone and configure:**
```powershell
git clone https://github.com/Malik-Adeen/call-quality-analytics
cd call-quality-analytics
```
Copy `.env` file manually (gitignored — bring it on a USB or send via chat).

**Step 3 — Edit Dockerfile.gpu for RTX 5060 (Blackwell):**

Change these 3 lines in `backend/Dockerfile.gpu`:

| Line | From | To |
|---|---|---|
| Base image | `FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04` | `FROM nvidia/cuda:12.8.0-cudnn9-runtime-ubuntu22.04` |
| PyTorch install | `torch==2.2.0+cu121` | `torch==2.7.0+cu128` |
| Index URL | `https://download.pytorch.org/whl/cu121` | `https://download.pytorch.org/whl/cu128` |

**Step 4 — Build and bring up:**
```powershell
docker compose up --build -d
```
Build takes 10-15 minutes. Do this before manager is watching.

**Step 5 — Seed demo data:**
```powershell
docker exec cq_api python scripts/reset_and_seed.py
```

**Step 6 — First pipeline run:**
- Upload one test audio file via UI
- Models download on first run (~3.5GB) — takes a few minutes
- Subsequent runs: ~30-60s per file

### Pending — Batch Test Phase 2 (on Adeen's machine, before or after tonight)
- Demo Tenant → sarah + marcus only (2 files)
- BPO Solutions → aisha + david + priya (3 files from bpo_solutions dir)
- Verify tenant isolation: Demo JWT sees only 2 calls, BPO JWT sees only 3, cross-tenant probe returns 404
- Write results to 55_BatchTest_Results.md

---

## Key Reminders

- Never run local `cq_redis` and `tunnel.bat` simultaneously (port 6379 conflict) — N/A now (Azure deleted)
- Thermal cap before WhisperX load: `nvidia-smi -pl 150`
- One file at a time through pipeline (gpu_queue concurrency=1)
- BatchAgent watch dirs: `E:\projects\call-quality-analytics\batch_watch\demo_tenant\` and `batch_watch\bpo_solutions\`
- BatchAgent config: `/config/tenants.json` inside container
- `.env` is gitignored — must be copied manually to any new machine

---

## Credentials

| Account | Email | Password |
|---|---|---|
| Demo Tenant Admin | admin@callquality.demo | admin1234 |
| BPO Solutions Admin | admin@bposolutions.demo | bpo1234 |
| Platform Admin | platform@callquality.internal | platform1234 |

---

## Key File Locations

| Purpose | Path |
|---|---|
| Project root | E:\projects\call-quality-analytics |
| Vault | E:\projects\docs |
| Demo audio (ElevenLabs) | C:\Users\adeen\Desktop\batch_audio\demo_tenant\ |
| BPO audio | C:\Users\adeen\Desktop\batch_audio\bpo_solutions\ |
| Audit report | E:\projects\docs\audit_report_20260510.md |
| Repo | https://github.com/Malik-Adeen/call-quality-analytics (private) |
