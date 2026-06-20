---
tags: [azure, deployment, runbook]
date: 2026-06-19
status: active
---

# 11 — Azure Deployment Runbook (v1.7 — B4ms CPU-Only)

> Single VM, all 9 services self-contained. No hybrid SSH tunnel. No GPU.
> WhisperX runs on CPU (small model, ~60-90s/call on B4ms — acceptable for SaaS demo + early customers).

---

## Architecture

```
Browser → nginx:80 (SPA + /api proxy + /ws proxy) → FastAPI:8000 (internal)
                                                   → PostgreSQL:5432 (127.0.0.1)
                                                   → Redis:6379 (127.0.0.1)
                                                   → MinIO:9000 (127.0.0.1)
                                                   → worker_io (io_queue, concurrency=4)
                                                   → worker_cpu (gpu_queue, concurrency=1, CPU WhisperX)
                                                   → Flower:5555 (127.0.0.1, basic auth)
```

Compose file: `infra/docker-compose.azure.yml` (standalone — not an override).

---

## Pre-flight (run locally before provisioning VM)

```bash
az --version                    # azure-cli 2.x
az account show                 # must show your subscription
git remote -v                   # must show github.com/Malik-Adeen/call-quality-analytics
ls infra/.env                   # must exist with all values filled
```

---

## Task 1 — Provision Azure B4ms VM

```bash
az group create --name callquality-rg --location eastus

az vm create \
  --resource-group callquality-rg \
  --name callquality-prod \
  --image Ubuntu2204 \
  --size Standard_B4ms \
  --location eastus \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-sku Standard

# Get IP (save this — used everywhere below)
az vm show -d --resource-group callquality-rg --name callquality-prod --query publicIps -o tsv

# Open ports
az vm open-port --resource-group callquality-rg --name callquality-prod --port 80 --priority 1000
az vm open-port --resource-group callquality-rg --name callquality-prod --port 22 --priority 1001
# Port 8000 intentionally NOT opened — nginx handles all traffic on 80
```

---

## Task 2 — Configure VM (SSH)

```bash
ssh azureuser@<VM_IP>

sudo apt-get update -y
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker azureuser
# Log out and back in for group to take effect
```

Optional: mount data disk for model cache persistence:
```bash
sudo mkfs.ext4 /dev/sdc
sudo mkdir -p /data/models
sudo mount /dev/sdc /data/models
echo '/dev/sdc /data/models ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

---

## Task 3 — Deploy

```bash
git clone https://github.com/Malik-Adeen/call-quality-analytics.git
cd call-quality-analytics
nano infra/.env
chmod 600 infra/.env
```

Fill `.env` — no placeholder values:
```
POSTGRES_USER=callquality
POSTGRES_PASSWORD=<strong>
POSTGRES_DB=callquality
REDIS_PASSWORD=<strong>
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=<strong>
MINIO_WEBHOOK_SECRET=<32-char>
JWT_SECRET=<64-char>
GROQ_API_KEY=<your-key>
OPENROUTER_API_KEY=<your-key>
HF_TOKEN=<your-token>
WHISPER_MODEL=small
MODEL_CACHE_HF=/data/models/huggingface
MODEL_CACHE_TORCH=/data/models/torch
FLOWER_USER=admin
FLOWER_PASSWORD=<strong>
CORS_ORIGINS=http://<VM_IP>
```

First build takes 10-15 min (npm ci + pip installs):
```bash
docker compose -f infra/docker-compose.azure.yml up -d --build
docker compose -f infra/docker-compose.azure.yml logs -f api
# Wait for: Application startup complete.
```

---

## Task 4 — Migrations

```bash
docker compose -f infra/docker-compose.azure.yml exec api alembic upgrade head
# Expected last line: Running upgrade -> 20260526_platform_rls_bypass

# Verify
docker compose -f infra/docker-compose.azure.yml exec api alembic current
# Expected: 20260526_platform_rls_bypass (head)

# Fallback if inconsistent state error:
# alembic stamp 20260526_platform_rls_bypass
```

---

## Task 5 — Seed

```bash
pip3 install psycopg2-binary bcrypt python-dotenv
cd ~/call-quality-analytics
python3 scripts/reset_and_seed.py
# Expected last line: Seeding complete.
```

---

## Task 6 — Verify

```bash
# API health
curl http://<VM_IP>/api/health
# Expected: {"success":true,"data":{"status":"ok"}}

# Port check (all non-nginx ports must be 127.0.0.1)
ss -tlnp | grep -E '5432|6379|9000|9001|8000|5555'
# Every line must show 127.0.0.1:PORT — never 0.0.0.0:PORT

# All containers up
docker compose -f infra/docker-compose.azure.yml ps
```

Open `http://<VM_IP>` in browser:
- Login page loads (Waaqi GRC design, teal primary)
- Login as `admin@callquality.demo / admin1234` → dashboard loads with seeded calls
- Status bar shows "Live" green pill (WebSocket connected)
- Upload `infra/test_pipeline.wav` → first run downloads WhisperX model (~244MB), subsequent runs ~60-90s
- Uploaded call appears in Call List with score after processing

---

## Cost Management

| Resource | Rate |
|---|---|
| Standard_B4ms (East US) | ~$0.19/hr |
| Daily (24h) | ~$4.56 |
| Monthly | ~$140 |

```bash
# Stop billing when not in use
az vm deallocate --resource-group callquality-rg --name callquality-prod

# Restart
az vm start --resource-group callquality-rg --name callquality-prod
```

---

## Phase 2 — GPU Upgrade Path

When call volume exceeds 80/day, migrate to `Standard_NC8as_T4_v3`:
- 8 vCPU, 56GB RAM, NVIDIA T4 (16GB VRAM)
- ~$0.75/hr PAYG / ~$0.42/hr 1-yr reserved
- WhisperX `large-v2` on T4: ~8-12s/min audio (vs. 90-120s CPU)
- Requires: CUDA 12.1, nvidia-container-toolkit, NCASv3_T4 Family quota request (0 by default, 1-3 days approval)
- Replace `Dockerfile.cpu` with `Dockerfile.gpu` in azure compose

---

## Known Issues (Audit 2026-06-19)

| Issue | Severity | Status |
|---|---|---|
| MinIO presigned URL double-prefix (audio playback) | Important | Pre-existing, frontend disabled — fix when re-enabling audio |
| `02_Database_Schema.sql` base schema not for Azure | Important | Do NOT run on Azure — use Alembic only |
| worker_io ships Playwright (~500MB waste) | Minor | Phase 2: separate Dockerfile.worker |
| Redis URL fallback in test containers | Minor | `os.environ["REDIS_URL"]` now enforced, no default |

---

## Retired: Hybrid Architecture (FYP Demo)

The former B2s + local GPU SSH tunnel architecture was retired after FYP demo (April 2026).
Historical reference: git history + [[24_Hybrid_Architecture_Postmortem]]
