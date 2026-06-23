---
tags:
  - azure
  - deployment
  - runbook
date: '2026-06-20'
status: active
---

# 11 — Azure Deployment Runbook (v1.9 — Split B4ms + NC4as_T4_v3)

> Two Azure VMs in the same VNet. App tier always-on. GPU tier on-demand/Spot.
> All cloud. No local GPU. No SSH tunnel to dev machine.

---

## Architecture

```
Browser → [B4ms App Tier]:80 (nginx) → FastAPI:8000 (127.0.0.1)
                                      → PostgreSQL:5432 (VNet)
                                      → Redis:6379 (VNet)
                                      → MinIO:9000 (VNet)
                                      → worker_io (io_queue, concurrency=4)
                                      → Flower:5555 (127.0.0.1)

[NC4as_T4_v3 GPU Tier] → worker_cpu (gpu_queue, concurrency=1, T4 CUDA)
                       → connects to B4ms Postgres/Redis/MinIO over VNet
```

Compose files:
- App tier: `infra/docker-compose.app.yml`
- GPU tier: `infra/docker-compose.gpu.yml`

---

## Pre-flight (run locally before provisioning)

```bash
az --version                 # azure-cli 2.x
az account show              # confirm subscription
git log --oneline -3         # confirm latest commit is pushed
ls infra/.env.prod           # must exist with all values filled
```

---

## Task 1 — Provision App Tier (B4ms)

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

APP_IP=$(az vm show -d -g callquality-rg -n callquality-prod --query publicIps -o tsv)
APP_PRIVATE_IP=$(az vm show -g callquality-rg -n callquality-prod --query "privateIps" -d -o tsv)
echo "Public: $APP_IP  Private: $APP_PRIVATE_IP"

az vm open-port -g callquality-rg -n callquality-prod --port 80 --priority 1000
az vm open-port -g callquality-rg -n callquality-prod --port 22 --priority 1001
```

---

## Task 2 — Configure App Tier VM

```bash
ssh azureuser@$APP_IP

sudo apt-get update -y
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker azureuser
# Log out and back in

# Optional: data disk for model cache
sudo mkfs.ext4 /dev/sdc
sudo mkdir -p /data/models
sudo mount /dev/sdc /data/models
echo '/dev/sdc /data/models ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

---

## Task 3 — Deploy App Tier

```bash
git clone https://github.com/Malik-Adeen/call-quality-analytics.git
cd call-quality-analytics

cp infra/.env.prod infra/.env
nano infra/.env
# Set CORS_ORIGINS=http://<APP_IP>
chmod 600 infra/.env

docker compose -f infra/docker-compose.app.yml up -d --build
docker compose -f infra/docker-compose.app.yml logs -f api
# Wait for: Application startup complete.
```

---

## Task 4 — Migrations

```bash
docker compose -f infra/docker-compose.app.yml exec api alembic upgrade head
# Expected last line: Running upgrade -> 20260526_platform_rls_bypass

docker compose -f infra/docker-compose.app.yml exec api alembic current
# Expected: 20260526_platform_rls_bypass (head)

# Fallback if inconsistent state error:
# docker compose -f infra/docker-compose.app.yml exec api alembic stamp 20260526_platform_rls_bypass
```

---

## Task 5 — Seed

```bash
pip3 install psycopg2-binary bcrypt python-dotenv
python3 scripts/reset_and_seed.py
# Expected last line: Seeding complete.
```

---

## Task 6 — Verify App Tier

```bash
curl http://$APP_IP/api/health
# Expected: {"success":true,"data":{"status":"ok"}}

# Port check — data services VNet-accessible, api internal
ss -tlnp | grep -E '5432|6379|9000|8000'
# 5432, 6379, 9000 → 0.0.0.0:PORT (VNet-accessible, NSG-protected)
# 8000 → 127.0.0.1:8000 (internal only)
```

Open `http://$APP_IP` — login as `admin@callquality.demo / admin1234`.

---

## Task 7 — Provision GPU Tier (NC4as_T4_v3)

Request NC quota first (0 by default, 1-3 business days):
```bash
# Check current quota
az vm list-usage --location eastus --query "[?name.value=='standardNCASv3_T4Family']" -o table

# Request if 0: Azure Portal → Subscriptions → Usage + quotas → NCASv3_T4 → Request increase → 4 cores
```

Provision (request Spot for cost savings — ~80% cheaper, retryable Celery tasks handle eviction):
```bash
# Spot
az vm create \
  --resource-group callquality-rg \
  --name callquality-gpu \
  --image Ubuntu2204 \
  --size Standard_NC4as_T4_v3 \
  --location eastus \
  --admin-username azureuser \
  --generate-ssh-keys \
  --priority Spot \
  --eviction-policy Deallocate \
  --public-ip-sku Standard

# Or on-demand (more reliable, ~$0.53/hr):
# Remove --priority and --eviction-policy flags

GPU_IP=$(az vm show -d -g callquality-rg -n callquality-gpu --query publicIps -o tsv)
GPU_PRIVATE_IP=$(az vm show -g callquality-rg -n callquality-gpu --query "privateIps" -d -o tsv)
echo "GPU Public: $GPU_IP  GPU Private: $GPU_PRIVATE_IP"
```

---

## Task 8 — Configure GPU VM

```bash
ssh azureuser@$GPU_IP

sudo apt-get update -y
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker azureuser

# NVIDIA Container Toolkit
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list \
  | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
# Log out and back in

# Model cache directory
sudo mkdir -p /data/models/huggingface /data/models/torch
sudo chown -R azureuser:azureuser /data/models
```

---

## Task 9 — Deploy GPU Tier

```bash
git clone https://github.com/Malik-Adeen/call-quality-analytics.git
cd call-quality-analytics

cp infra/.env.gpu.example infra/.env
nano infra/.env
# Fill: all secrets (copy from .env.prod values)
# Set: APP_TIER_HOST=<APP_PRIVATE_IP>
chmod 600 infra/.env

docker compose -f infra/docker-compose.gpu.yml up -d --build
docker compose -f infra/docker-compose.gpu.yml logs -f
# First run downloads WhisperX large-v2 (~3GB) + Pyannote models — takes 5-15 min
```

---

## Task 10 — NSG Rules

```bash
# Run from your local machine (not the VMs)
# Script auto-discovers GPU private IP and applies rules
chmod +x infra/nsg-runbook.sh
./infra/nsg-runbook.sh
# Restricts 5432/6379/9000 to GPU private IP only; denies those ports from internet
```

---

## Task 11 — E2E Verify

```bash
# Upload test file via dashboard
# Open http://$APP_IP → Upload → infra/test_pipeline.wav
# Expected: call appears in Call List with score ~90-120s later (first run longer — model download)

# Celery task visibility
# Flower at http://$APP_IP/... not public — SSH tunnel to view:
# ssh -L 5555:127.0.0.1:5555 azureuser@$APP_IP
# Then open http://localhost:5555 (FLOWER_USER / FLOWER_PASSWORD)
```

---

## Cost Management

| Resource | Rate |
|---|---|
| B4ms (always-on) | ~$0.12/hr (~$87/mo) |
| NC4as_T4_v3 on-demand | ~$0.53/hr |
| NC4as_T4_v3 Spot | ~$0.11-0.20/hr |
| Realistic (GPU ~4hr/day Spot) | ~$100-110/mo total |

```bash
# Deallocate GPU tier when not needed (stops billing)
az vm deallocate -g callquality-rg -n callquality-gpu

# Start GPU tier when calls are queued
az vm start -g callquality-rg -n callquality-gpu

# App tier should stay up — deallocate only for maintenance
az vm deallocate -g callquality-rg -n callquality-prod
```

---

## Known Issues

| Issue | Severity | Status |
|---|---|---|
| MinIO presigned URL double-prefix (audio playback) | Important | Frontend disabled — fix when re-enabling audio |
| `02_Database_Schema.sql` not for Azure | Important | Do NOT run on Azure — Alembic only |
| worker_io ships Playwright (~500MB waste) | Minor | Phase 2: separate Dockerfile.worker |
| First GPU run downloads ~3GB models | Expected | Subsequent calls use cache at /data/models |
| NC4as_T4_v3 quota is 0 by default | Blocker | Request in portal 1-3 days before deploy |

---

## Retired

- Single B4ms CPU-only architecture → retired (CPU WhisperX 90-120s/call, unacceptable for production)
- `infra/docker-compose.azure.yml` → kept as single-box CPU reference only, not for production deploy
- Hybrid Azure B2s + local GPU SSH tunnel → retired after FYP demo (April 2026) — see [[24_Hybrid_Architecture_Postmortem]]
