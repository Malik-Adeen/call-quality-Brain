---
tags:
  - postmortem
  - deployment
  - blackwell
date: '2026-06-25'
status: resolved
---

# 64 — Fahad Demo Deployment Postmortem (2026-06-24 to 2026-06-25)

> Full timeline of every failure, decision, and resolution during the Blackwell GPU deployment.
> Reference this when deploying to new environments or debugging similar stacks.

---

## Environment

- **Machine:** Fahad's Windows laptop — RTX 5060 8GB (Blackwell sm_120), 64GB RAM
- **OS:** Windows 11 + Docker Desktop + WSL2 Ubuntu
- **CUDA:** 12.8 (inside containers)
- **PyTorch:** 2.7.0+cu128
- **Target:** http://callquality.giize.com via Dynu DDNS
- **Branch:** deploy/fahad-demo

---

## Phase 1: Infrastructure Wiring

### Problem: docker-compose.gpu.yml had TODO placeholders
`APP_TIER_HOST=TODO_SET_TO_ACTUAL_APP_TIER_IP` — all service URLs broken.

**Decision:** Hardcode actual Docker service hostnames (`cq_postgres`, `cq_redis`, `cq-minio`) instead of using an env variable. Rationale: these are internal Docker network names that don't change between environments.

**Outcome:** ✅ Fixed. Worker containers can now reach all services.

### Problem: GPU worker on wrong Docker network
Worker joined `infra_default` network, all app services on `infra_cq_network`. Redis connection refused.

**Decision:** Add explicit network config to docker-compose.gpu.yml pointing to the external `infra_cq_network`.

**Outcome:** ✅ Fixed. `docker exec cq_worker_gpu python -c "import redis; redis.Redis('cq_redis').ping()"` returned True.

### Problem: nginx rejecting uploads (413)
Test file (3.5MB) exceeded default nginx 1MB body limit.

**Decision:** Add `client_max_body_size 200m;` to nginx.conf.

**Outcome:** ✅ Fixed. Uploads now accepted.

### Problem: .env.prod had stale CORS origin
`CORS_ORIGINS=http://adeen.dynu.net` — wrong domain.

**Decision:** Update to `http://callquality.giize.com`.

**Outcome:** ✅ Fixed.

---

## Phase 2: GPU Worker Build (Blackwell Compatibility)

### Problem: en_core_web_lg spaCy model not found
`COPY` of local `.whl` file failed because the file didn't exist in build context.

**Decision:** Replace `COPY + pip install` with direct pip install from GitHub releases URL. Avoids needing the file locally.

**Outcome:** ✅ Fixed. Spacy model installs during build.

### Problem: Build verified but CUDA check
**Verification:**
```
docker exec cq_worker_gpu python -c "import torch; print(torch.cuda.get_device_name(0))"
→ NVIDIA GeForce RTX 5060 Laptop GPU
```
✅ Blackwell GPU recognized, CUDA 12.8 confirmed.

---

## Phase 3: PyTorch 2.7 weights_only Breaking Change

### Problem: UnpicklingError on pyannote checkpoint loading
```
_pickle.UnpicklingError: Weights only load failed.
GLOBAL omegaconf.listconfig.ListConfig was not an allowed global
```

**Root cause:** PyTorch 2.7 changed `torch.load` default from `weights_only=False` to `weights_only=True`. Pyannote VAD checkpoint contains omegaconf types (ListConfig, DictConfig, ContainerMetadata) which are blocked under `weights_only=True`.

**Decision sequence:**

1. **Attempt 1:** `add_safe_globals([ListConfig, DictConfig])` — failed, ContainerMetadata still blocked.
2. **Attempt 2:** `add_safe_globals([ListConfig, DictConfig, ContainerMetadata])` + `setdefault('weights_only', False)` — failed. Lightning_fabric *explicitly* passes `weights_only=True`, so `setdefault` is a no-op.
3. **Attempt 3 (working):** Force override with `kwargs['weights_only'] = False` in the monkeypatch. This overwrites whatever lightning_fabric passes.

**Final fix:**
```python
_orig_torch_load = torch.load
def _patched_torch_load(*args, **kwargs):
    kwargs['weights_only'] = False  # NOT setdefault — must force override
    return _orig_torch_load(*args, **kwargs)
torch.load = _patched_torch_load
```

**Lesson:** `setdefault` vs direct assignment matters when callers explicitly pass the kwarg. Always check the call stack to see if the kwarg is being explicitly passed by intermediate libraries.

**Outcome:** ✅ Fixed after attempt 3.

---

## Phase 4: cuDNN Version Mismatch (SIGABRT)

### Problem: Worker process crashes with signal 6 (SIGABRT)
```
Could not load library libcudnn_ops_infer.so.8
Worker exited prematurely: signal 6 (SIGABRT)
```

**Root cause:** CTranslate2 4.4.0 (installed in image) was built against cuDNN 8. The CUDA 12.8 base image ships cuDNN 9. `libcudnn_ops_infer.so.8` is a cuDNN 8 file that does not exist in cuDNN 9.

**Attribution note:** Initial analysis blamed speechbrain/pyannote. Incorrect. PyTorch bundles its own cuDNN copy internally — torch-based libraries never touch the system cuDNN. CTranslate2 is the only library in this stack that links the system cuDNN directly.

**Decision options considered:**
1. `apt install libcudnn8` — rejected. NVIDIA's apt repos for CUDA 12.8 may not serve cuDNN 8. Unpredictable failure mode.
2. `pip install nvidia-cudnn-cu12==8.9.7.29` + `LD_LIBRARY_PATH` — attempted, abandoned. Too fragile.
3. **Upgrade CT2 to ≥4.5.0** — chosen. CT2 4.5+ targets cuDNN 9. The base image already has cuDNN 9. No additional libraries needed.
4. `DIARIZE_DEVICE=cpu` — identified as fallback if CT2 upgrade failed.

**Decision:** Upgrade CT2 in the running container first (no rebuild), then pin in Dockerfile.

```bash
docker exec cq_worker_gpu pip install "ctranslate2>=4.5.0"
# Installed: 4.8.0
```

**Outcome:** ✅ SIGABRT eliminated. WhisperX ran successfully.

**Dockerfile change:** `ctranslate2>=4.4.0` → `ctranslate2==4.8.0` (pinned to exact known-working version).

**Also removed:** `nvidia-cudnn-cu12==8.9.7.29` install and `LD_LIBRARY_PATH=/opt/cudnn8` ENV — these were the failed attempt 2 remnants. Removed to keep image clean.

---

## Phase 5: calls.py — MissingGreenlet + TabError

### Problem: Upload returns 500 — MissingGreenlet
```
sqlalchemy.exc.MissingGreenlet: greenlet_spawn has not been called
at: calls.py line 423, current_user.tenant_id
```

**Root cause:** `current_user.tenant_id` was accessed in the `except` block after `await db.rollback()`. After rollback, SQLAlchemy expires all ORM objects. Accessing `tenant_id` triggers a lazy load, which requires an async greenlet context that doesn't exist in the except handler.

**Fix:** Cache `tenant_id = current_user.tenant_id` as a local variable at the top of the function, before any DB operations. Use the local variable in all except/finally blocks.

**Outcome:** ✅ Fixed. Uploads return 202.

### Problem: TabError on next hot reload
Notepad introduced a tab character when Fahad manually edited calls.py. Python 3.11 is strict about mixed tabs/spaces.

**Fix:** Replaced file wholesale via `docker cp` with a clean version.

**Lesson:** Never edit Python files in Notepad/Wordpad. Always use Zed, VS Code, or similar. The docker cp workflow is the correct approach for GPU worker files regardless.

---

## Phase 6: Groq API Key Revoked

### Problem: extract_agent_identity → 401 Unauthorized
```
HTTP Request: POST https://api.groq.com/openai/v1/chat/completions "HTTP/1.1 401 Unauthorized"
```

**Root cause:** The Groq API key in `infra/.env` was revoked.

**Discovery issue:** Updated `infra/.env.prod` first. Worker still showed old key. Docker Compose loads `infra/.env` by default alongside `infra/.env.prod` — when both define the same variable, `.env` wins (loaded first by convention). `.env.prod` values were being silently overridden.

**Fix:** Update `infra/.env` directly:
```bash
sed -i 's|GROQ_API_KEY=gsk_old...|GROQ_API_KEY=gsk_new...|' infra/.env
sudo docker compose -f infra/docker-compose.app.yml --env-file infra/.env.prod up -d --force-recreate worker_io
```

**Lesson:** Always update BOTH `infra/.env` AND `infra/.env.prod` for any secret change. They must stay in sync.

**Outcome:** ✅ Fixed. Groq returning 200.

---

## Phase 7: Auth RLS Blocking Login

### Problem: Login always returns "Invalid email or password" despite correct credentials
**Root cause:** `users` table has RLS enabled with this policy:
```sql
(tenant_id = current_setting('app.current_tenant')::uuid)
OR (current_setting('app.platform_bypass') = 'true')
```

The login endpoint runs before any tenant context is set. RLS filters out all rows → `user = None` → 401.

**This is a pre-existing bug** that only became visible after a full container restart cleared any cached DB session state.

**Decision:** Add `set_config('app.platform_bypass', 'true', true)` before the user SELECT in auth.py.

```python
await db.execute(text("SELECT set_config('app.platform_bypass', 'true', true)"))
result = await db.execute(select(User).where(User.email == body.email))
```

**Why `true` as third argument:** `SET LOCAL` scope — resets after the transaction. Safe.

**Why not fix in database.py get_db:** The login query has no tenant context yet by design. The bypass is appropriate here. The correct long-term fix would be a dedicated `get_db_no_rls` dependency for auth endpoints.

**Outcome:** ✅ Login working.

---

## Phase 8: nginx Stale DNS Cache

### Problem: Login returns 502 despite API container running
Nginx error: `connect() failed (111: Connection refused) upstream: http://172.19.0.3:8000/auth/login`

**Root cause:** `cq_api` container was restarted and got a new Docker-assigned IP (`172.19.0.2`). Nginx cached the old IP (`172.19.0.3`) from the previous container lifecycle.

**Fix:**
```bash
docker exec cq_nginx nginx -s reload
```

`nginx -s reload` forces re-resolution of all upstream hostnames. Takes effect immediately.

**Lesson:** Any time a container restarts and something else can't reach it via hostname, reload nginx. This should be part of the standard restart runbook.

**Outcome:** ✅ Fixed immediately on reload.

---

## Phase 9: Dedup Constraint Removal

### Problem: Re-uploading the same file returns 500 (demo-breaking)
Unique constraint `uq_calls_tenant_audio_path` on `(tenant_id, minio_audio_path)` blocks re-upload of the same file.

**Decision:** Remove the constraint for the demo branch. Rationale: demo requires uploading the same test file multiple times. The constraint is a data integrity feature, not a security feature — it can be re-added post-demo with proper UI handling for duplicates.

**Steps:**
1. Drop live: `ALTER TABLE calls DROP CONSTRAINT IF EXISTS uq_calls_tenant_audio_path;`
2. Remove from Alembic migration `20260621_idempotency_constraints.py` so fresh deploys don't recreate it

**Outcome:** ✅ Removed. Same file can be uploaded multiple times.

---

## Phase 10: Remote Access Setup (Tailscale + Zed)

### Problem: No remote code editing capability
Previously: changes required copy-pasting code in chat, Fahad manually editing, risking formatting issues (Notepad TabError).

**Solution implemented:**
1. Tailscale approval (Adeen joined Fahad's tailnet)
2. WSL2 SSH server enabled
3. Windows `netsh portproxy` to forward Tailscale IP port 22 → WSL2 IP port 22
4. SSH key auth configured (ed25519 key generated, copied via ssh-copy-id)
5. Zed remote SSH connected to `fahad@100.118.221.10`

**Docker access from WSL2:** Requires `sudo docker` — Docker Desktop WSL2 integration must be enabled in Docker Desktop settings.

**Outcome:** ✅ Full remote edit + terminal access via Zed. `docker cp` workflow now replaced by direct file editing.

---

## Summary: Every Error and Its Category

| Error | Category | Root Cause | Fix |
|---|---|---|---|
| TODO placeholder hosts | Config | Missing env setup | Hardcode Docker hostnames |
| Wrong Docker network | Config | Network not declared | Add external network to compose |
| nginx 413 | Config | Default 1MB limit | client_max_body_size 200m |
| spaCy wheel missing | Build | Local file not in context | pip from GitHub URL |
| UnpicklingError ListConfig | PyTorch compat | weights_only=True default in 2.7 | monkeypatch torch.load |
| UnpicklingError ContainerMetadata | PyTorch compat | setdefault doesn't override explicit kwarg | Direct assignment kwargs['weights_only'] = False |
| SIGABRT libcudnn_ops_infer.so.8 | Dependency compat | CT2 4.4 linked cuDNN 8, image has cuDNN 9 | Upgrade CT2 to 4.8.0 |
| MissingGreenlet tenant_id | Async ORM | Expired ORM object accessed after rollback | Cache tenant_id before DB ops |
| TabError | Editor | Notepad mixed tabs/spaces | docker cp clean file |
| Groq 401 | Config | Revoked key + .env override | Update infra/.env, not just .env.prod |
| Login 401 | RLS | No tenant context at login time | set_config platform_bypass before user SELECT |
| nginx 502 | Networking | Stale cached container IP | nginx -s reload |
| Upload 500 dedup | DB constraint | Same file hash = constraint violation | Drop uq_calls_tenant_audio_path |

---

## Decisions That Differ From Master Branch

| Decision | Master | deploy/fahad-demo | Rationale |
|---|---|---|---|
| CT2 version | `>=4.4.0` | `==4.8.0` | Blackwell + CUDA 12.8 requires cuDNN 9 support |
| cuDNN 8 workaround | Present | Removed | Obsolete after CT2 upgrade |
| torch.load | Default | Monkeypatched | PyTorch 2.7 breaking change |
| Auth RLS bypass | Missing | Added | Pre-existing bug, only visible on full restart |
| Dedup constraint | Present | Removed | Demo usability |
| Groq key | Old | New | Revoked key replaced |

---

## What Will Break on a Full Rebuild

Nothing — all fixes are now in code files:
- `Dockerfile.gpu.blackwell` pins CT2 4.8.0 and removes cuDNN 8
- `whisper_service.py` has the monkeypatch
- `auth.py` has the RLS bypass
- `alembic/versions/20260621_idempotency_constraints.py` no longer creates the dedup constraint
- `infra/.env` has the new Groq key (not committed — must be managed manually per deployment)
