---
tags: [moc, dashboard]
status: active
created: 2026-04-11
updated: 2026-04-17
---

# 00 — Master Dashboard

> Single entry point. Always read this first.

---

## Project Identity

| Property | Value |
|---|---|
| **System** | AI Call Quality & Agent Performance Analytics System |
| **Demo Date** | Tue/Wed/Thu — week of April 21, 2026 |
| **Repo** | github.com/Malik-Adeen/call-quality-analytics |
| **Local** | N:\projects\call-quality-analytics |
| **Vault** | N:\projects\docs |
| **Azure B2s** | `20.228.184.111` East US |

---

## Build State — v1.4 DEMO READY

| Phase | Status |
|---|---|
| Phase 1 — Foundation | ✅ |
| Phase 2 — AI Pipeline | ✅ |
| Phase 3 — React Dashboard | ✅ |
| Phase 4 — PDF + Azure + Hybrid | ✅ |
| Real audio testing (5 files) | ✅ |
| Presidio extended (zip, SSN, account) | ✅ |
| **Demo dry-run** | 🔲 |

---

## Pre-Demo Checklist

- [ ] Demo dry-run — full script solo rehearsal
- [ ] `git pull` + `docker restart cq_worker_io` on Azure VM
- [ ] `reset_and_seed.py` on Azure VM — clean 200 calls
- [ ] Verify Presidio fix on bpo_inbound_1 reupload
- [ ] Confirm `http://20.228.184.111:8000/health` responds

---

## Demo Start Sequence

```
1. nvidia-smi → memory.free > 5000 MiB
2. tunnel.bat → SSH connects silently
3. docker compose -f infra/docker-compose.hybrid.yml up -d worker_gpu
4. docker logs cq_worker_gpu --tail 5 → sync with worker_io
5. cd frontend && npm run dev
6. http://localhost:5173 → login
7. Upload tech_support.mp3 → Reports page → wait for toast
```

---

## Real Audio Results

| File | Score | Demo? |
|---|---|---|
| tech_support.mp3 | 88.2% | ✅ Primary |
| billing_dispute.mp3 | 88.3% | ✅ Backup |
| irate_customer.mp3 | 71.0% | ⚠️ Needs trim |
| bpo_inbound_1.mp3 | 75.1% | ℹ️ Labels swapped |

---

## Architecture

```
Browser (localhost:5173)
    ↓ Vite proxy
Azure B2s (20.228.184.111:8000)
    FastAPI · PostgreSQL · Redis · MinIO · worker_io · Flower
    ↕ Celery gpu_queue via SSH tunnel
Local RTX 3060 Ti
    worker_gpu · WhisperX large-v2 · ~33s inference
```

---

## Critical Invariants

1. Audio → MinIO only, never DB
2. Raw transcript → never DB, Presidio-redacted only
3. `pii_redacted = TRUE` before downstream tasks
4. `run_whisperx` → `gpu_queue`, concurrency=1
5. JWT → sessionStorage, never localStorage
6. Groq: `llama-3.3-70b-versatile`
7. MinIO: `cq-minio:9000`
8. Score: 0–10 × 10 = %
9. Zero code comments

---

## Post-Mortems

[[07]] [[08]] [[09]] [[11]] [[12]] [[13]] [[14]] [[16]] [[17]] [[21]] [[23]] [[24]] [[26]] [[27]]

## Reference

[[01_Master_Architecture]] · [[03_API_Contract]] · [[11_Azure_Deployment]] · [[22_Session_Handoff]]
