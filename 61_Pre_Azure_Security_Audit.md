---
tags: [security, pre-azure, audit]
date: 2026-05-25
---

# 61 — Pre-Azure Security Audit

> Sources: Perplexity (CVEs), DeepSeek (Docker/container), GPT (PIPEDA/Azure), GLM (multi-tenancy).
> Cross-referenced against actual codebase. 9 real findings. 6 ghost findings invalidated.
> Run Claude Code script (section 4) to confirm all P0 fixes before Azure push.

---

## 1. Invalid Findings (Do Not Chase)

These were raised by GLM but are already correctly handled in the codebase:

| Finding | Why Invalid |
|---|---|
| call_metrics / sentiment_timeline missing tenant_id | ORM has `tenant_id` on both tables |
| Flower unauthenticated | docker-compose has `--basic_auth=${FLOWER_USER}:${FLOWER_PASSWORD}` |
| WS `user_id` path not validated vs JWT | `ws.py` line: `if str(payload.get("sub")) != user_id: close(4001)` |
| WS broadcast leaks across tenants | `broadcast()` filters: `if tid != tenant_id: continue` |
| Redis pub/sub shared channel | Channel is `ws:broadcast:{tenant_id}` — already namespaced |
| JWT `tenant_id` sourced from JWT not DB | `dependencies.py` reads `user.tenant_id` from DB, not JWT claim |

---

## 2. Confirmed Findings — Priority Order

### P0 — Fix Before Any Cloud Push or External Demo

---

**P0-1: Redis has no authentication**
- Source: DeepSeek, GLM
- File: `infra/docker-compose.yml`
- Detail: `redis` service has no `--requirepass`. Port 6379 is published to the host. Any container on `cq_network` — or any process on the host — can read/write all Celery queues, inject tasks, and access all pub/sub channels.
- Fix: Add `--requirepass ${REDIS_PASSWORD}` to redis command. Add `REDIS_PASSWORD` to `.env`. Update `REDIS_URL` in all services to `redis://:${REDIS_PASSWORD}@cq_redis:6379/0`. Remove host port mapping `6379:6379`.

---

**P0-2: python-jose JWT bomb DoS (CVE-2024-33664)**
- Source: Perplexity
- File: `backend/requirements.txt`
- Detail: `python-jose` through 3.3.0 allows resource exhaustion via malformed JWE tokens. Any endpoint that calls `decode_access_token()` is vulnerable to a DoS from unauthenticated requests.
- Fix: Replace `python-jose[cryptography]` with `PyJWT[crypto]>=2.8.0` in requirements.txt. Update `backend/app/auth/jwt.py` accordingly. PyJWT is actively maintained and does not have this vulnerability.

---

**P0-3: MinIO unversioned — OOM CVE active**
- Source: Perplexity, DeepSeek
- File: `infra/docker-compose.yml`
- Detail: `image: minio/minio` (no tag = `latest`). An OOM vulnerability in MinIO S3 Select exploitable by authenticated users via crafted CSV input affects releases before RELEASE.2025-12-20. Also breaks reproducibility.
- Fix: Pin to `minio/minio:RELEASE.2025-12-20T10-18-58Z` or later. Same for `minio/mc`.

---

**P0-4: Redis image unversioned — critical CVEs May 2026**
- Source: Perplexity
- File: `infra/docker-compose.yml`
- Detail: `image: redis:7-alpine` is not pinned to a specific release. Redis OSS had multiple critical CVEs fixed in the May 5 2026 advisory (unauthorized data access, possible RCE).
- Fix: Pin to `redis:7.4-alpine` or the specific patched release. Run `pip-audit` and `docker scout` to confirm.

---

**P0-5: `write_scores` DELETE unscoped by tenant_id**
- Source: GLM, codebase verification
- File: `backend/app/pipeline/tasks.py`
- Detail: `db.execute(delete(CallMetrics).where(CallMetrics.call_id == call_id))` — no `tenant_id` filter. Same for `SentimentTimeline`. If SET LOCAL fails or RLS is misconfigured, this DELETE is tenant-unscoped. Defense-in-depth requires the filter regardless.
- Fix: Add `CallMetrics.tenant_id == UUID(tenant_id)` to both DELETE statements.

---

**P0-6: No rate limiting on `/auth/login` and `/auth/register`**
- Source: GPT, GLM
- File: `backend/app/routers/auth.py`
- Detail: `/auth/login` has no brute-force protection. `/auth/register` has no throttle — anyone can create unlimited tenants and exhaust the GPU queue and MinIO storage.
- Fix: Add `slowapi` rate limiter. Login: 10 requests/minute per IP. Register: 3 requests/hour per IP.

---

### P1 — Fix Before First Paying Customer

---

**P1-1: worker_gpu runs as root**
- Source: DeepSeek
- File: `backend/Dockerfile.gpu.blackwell`, `backend/Dockerfile.gpu`
- Detail: No `USER` directive. Celery runs as root inside the container. A compromised GPU worker has full container filesystem access.
- Fix: Add `RUN useradd -m appuser && usermod -aG video,render appuser` + `USER appuser` to both GPU Dockerfiles.

---

**P1-2: All internal service ports exposed to host**
- Source: DeepSeek
- File: `infra/docker-compose.yml`
- Detail: `postgres:5432`, `redis:6379`, `minio:9000/9001`, `flower:5555` all published to `0.0.0.0`. In production these should not be reachable from outside the host.
- Fix: For local dev, bind to `127.0.0.1` only (e.g., `"127.0.0.1:5432:5432"`). For Azure, remove all port mappings except `api:8000` — everything else communicates over the Docker network or VNet.

---

**P1-3: Dev volume mounts baked into docker-compose**
- Source: DeepSeek
- File: `infra/docker-compose.yml`
- Detail: `../backend:/app` mounted into `api`, `worker_io`, `worker_gpu`. This overwrites the built image's code with the host directory at runtime. Any file change on the host instantly affects running containers. Incompatible with production.
- Fix: Remove volume mounts for Azure deployment. Code should be baked into the image via `COPY`. Use a separate `docker-compose.dev.yml` override for local mounts.

---

**P1-4: CORS hardcoded to `localhost:5173`**
- Source: Codebase
- File: `backend/app/main.py`
- Detail: `allow_origins=["http://localhost:5173"]`. In Azure, the frontend will have a different origin. This will silently block all browser requests in production.
- Fix: Move to `CORS_ORIGINS` env var. Parse as comma-separated list.

---

**P1-5: Flat Docker network — no segmentation**
- Source: DeepSeek
- Detail: Single `cq_network`. API can directly reach Postgres, Redis, MinIO. No lateral movement barrier.
- Fix for Azure: VNet subnets handle this at infra level. For local Docker, split into `frontend_net` (api, worker_io) and `backend_net` (postgres, redis, minio, worker_gpu).

---

**P1-6: MinIO init mounts host file without `:ro`**
- Source: DeepSeek
- File: `infra/docker-compose.yml`
- Detail: `./test_pipeline.wav:/tmp/test_pipeline.wav` — writable bind mount. Add `:ro`.
- Fix: `./test_pipeline.wav:/tmp/test_pipeline.wav:ro`

---

### P2 — Azure Hardening (Pre-Go-Live)

From GPT's 80-item checklist, the ones not already covered above:

- All secrets migrated to Azure Key Vault (no `.env` on VMs)
- Managed identities for all compute → Key Vault RBAC
- PostgreSQL Flexible Server — private networking, no public endpoint
- NSGs: deny all inbound by default, allow only approved ports per subnet
- Groq ZDR enabled — verify in Groq console before first call processed
- TLS 1.2+ enforced at Application Gateway / ingress
- JWT: add `aud` and `iss` claim validation
- MFA enforced for TENANT_ADMIN and PLATFORM_ADMIN roles
- GitHub secret scanning enabled on repo
- Azure Defender for Cloud recommendations reviewed
- Backup + restore tested before cutover
- Incident response plan documented (PIPEDA breach = 72-hour OPC notification)

---

## 3. Claude Code Audit Script

Run this in the terminal from `E:\projects\call-quality-analytics`:

```bash
cd E:\projects\call-quality-analytics

echo "=== BANDIT: Python security scan ===" 
cd backend && pip install bandit pip-audit --quiet
bandit -r app/ -ll -f txt
echo ""

echo "=== PIP-AUDIT: Dependency CVEs ==="
pip-audit -r requirements.txt -r requirements-gpu.txt
echo ""

echo "=== NPM AUDIT: Frontend ==="
cd ../frontend && npm audit
cd ..
echo ""

echo "=== GREP: Redis requirepass ==="
grep -n "requirepass\|REDIS_PASSWORD" infra/docker-compose.yml infra/.env

echo "=== GREP: Root user in Dockerfiles ==="
grep -n "USER" backend/Dockerfile backend/Dockerfile.gpu backend/Dockerfile.gpu.blackwell 2>/dev/null || echo "NO USER DIRECTIVE FOUND — running as root"

echo "=== GREP: MinIO image pinned ==="
grep -n "minio/minio\|minio/mc" infra/docker-compose.yml

echo "=== GREP: Redis image pinned ==="
grep -n "image: redis" infra/docker-compose.yml

echo "=== GREP: Dev volume mounts ==="
grep -n "../backend:/app" infra/docker-compose.yml

echo "=== GREP: CORS origins ==="
grep -n "allow_origins\|CORS_ORIGINS" backend/app/main.py backend/app/config.py

echo "=== GREP: python-jose in requirements ==="
grep -n "python-jose\|PyJWT" backend/requirements.txt

echo "=== GREP: Rate limiting ==="
grep -rn "slowapi\|RateLimiter\|limiter" backend/app/routers/auth.py

echo "=== GREP: write_scores tenant_id filter ==="
grep -n "delete(CallMetrics)\|delete(SentimentTimeline)" backend/app/pipeline/tasks.py

echo "=== GREP: Exposed ports ==="
grep -n "ports:" -A2 infra/docker-compose.yml

echo "=== GREP: minio_init volume ro flag ==="
grep -n "test_pipeline.wav" infra/docker-compose.yml

echo "=== INVARIANT: audio_path never used ==="
grep -rn "audio_path" backend/app/ --include="*.py" | grep -v "minio_audio_path"

echo "=== INVARIANT: localStorage never used for JWT ==="
grep -rn "localStorage" frontend/src/ --include="*.ts" --include="*.tsx"

echo "=== AUDIT COMPLETE ==="
```

---

## 4. Fix Checklist

- [ ] P0-1: Redis `--requirepass` + remove port 6379 from host
- [ ] P0-2: Replace `python-jose` with `PyJWT>=2.8.0`
- [ ] P0-3: Pin MinIO image to `RELEASE.2025-12-20T10-18-58Z` or later
- [ ] P0-4: Pin Redis image to `redis:7.4-alpine`
- [ ] P0-5: Add `tenant_id` filter to both DELETEs in `write_scores`
- [ ] P0-6: Add `slowapi` rate limiting to `/auth/login` and `/auth/register`
- [ ] P1-1: Non-root user in Dockerfile.gpu + Dockerfile.gpu.blackwell
- [ ] P1-2: Bind all dev ports to `127.0.0.1`
- [ ] P1-3: Remove volume mounts from docker-compose (use override for dev)
- [ ] P1-4: CORS_ORIGINS from env var
- [ ] P1-5: `:ro` on test_pipeline.wav mount
