---
tags: [azure, deployment, demo-day]
date: 2026-04-16
status: reference
---

## Region Decision

Both VMs deploy to **East US** — the only region where:
- NC4as_T4_v3 GPU quota can be requested on a Student account
- B2s has confirmed availability
- API and GPU worker communicate over Azure internal network (zero egress cost, zero latency)

Pakistan → East US latency (~180ms) is acceptable for a dashboard demo.
Pakistan → Central India routing is worse due to geopolitical peering — traffic bounces through Middle East/Europe.

---

## Azure B2s — Always-On Demo Server

### Provision

```bash
az vm create \
  --resource-group callquality-rg \
  --name callquality-b2s \
  --image Ubuntu2204 \
  --size Standard_B2s \
  --location eastus \
  --admin-username azureuser \
  --admin-password "CallQuality@2026!" \
  --public-ip-sku Standard \
  --no-wait
```

Wait 2 minutes then get IP:

```bash
az vm show -d --resource-group callquality-rg --name callquality-b2s --query publicIps -o tsv
```

### Open ports

```bash
az vm open-port --resource-group callquality-rg --name callquality-b2s --port 8000 --priority 1001
az vm open-port --resource-group callquality-rg --name callquality-b2s --port 5555 --priority 1002
```

### SSH in

```bash
ssh azureuser@<PUBLIC_IP>
```

### Install Docker + git

```bash
sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose-plugin git python3-pip
sudo usermod -aG docker azureuser
newgrp docker
```

### Deploy

```bash
git clone https://github.com/Malik-Adeen/call-quality-analytics.git
cd call-quality-analytics
nano infra/.env
```

Fill in `.env` with all real values (copy from local `infra/.env`).

```bash
docker compose -f infra/docker-compose.yml up -d --build
pip3 install psycopg2-binary bcrypt python-dotenv
python3 scripts/reset_and_seed.py
```

### Verify

```bash
docker compose -f infra/docker-compose.yml ps
curl http://localhost:8000/health
```

Open `http://<PUBLIC_IP>:8000/health` in browser — should return `{"status":"ok"}`.

**Estimated cost:** Standard_B2s ~$0.042/hr × 240hr (10 days) = ~$10.00

---

## Azure NC4as_T4_v3 — GPU (T4 16GB) — Pending Quota Approval

Deploy in **East US** — same region as B2s so workers communicate over internal network.

### Quota request (portal.azure.com)

1. Quotas → Compute → filter `NCSv3`
2. Select East US row → Request quota increase
3. New limit: **4** vCPUs
4. Justification: University final year project demo. Requires NVIDIA T4 GPU for real-time Urdu speech transcription using WhisperX large-v2. Demo scheduled within 10 days. Requesting minimum 4 vCPUs for NC4as_T4_v3 for approximately 4 hours of usage.

### Provision (only after quota approved)

```bash
az vm create \
  --resource-group callquality-rg \
  --name callquality-t4 \
  --image Ubuntu2204 \
  --size Standard_NC4as_T4_v3 \
  --location eastus \
  --admin-username azureuser \
  --admin-password "CallQuality@2026!" \
  --public-ip-sku Standard \
  --no-wait
```

### GPU setup (SSH in)

```bash
ssh azureuser@<T4_PUBLIC_IP>

sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose-plugin git python3-pip
sudo usermod -aG docker azureuser
newgrp docker

distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update -y && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

git clone https://github.com/Malik-Adeen/call-quality-analytics.git
cd call-quality-analytics
nano infra/.env
```

Set in `.env`:
```
WHISPER_DEVICE=cuda
WHISPER_MODEL=large-v2
```

```bash
docker compose -f infra/docker-compose.yml up -d --build worker_gpu
docker exec cq_worker_gpu nvidia-smi
docker exec cq_worker_gpu python3 -c "import torch; print(torch.cuda.is_available())"
```

### STOP IMMEDIATELY AFTER DEMO

```bash
az vm deallocate --resource-group callquality-rg --name callquality-t4
```

**Estimated cost:** ~$0.526/hr × 4hr = ~$2.10

---

## Fallback Plan (if GPU quota not approved)

Local RTX 3060 Ti handles all live pipeline demos.
- Already verified: `test_call.mp3` → `score=92%` in ~33s
- B2s serves the always-on dashboard with seeded data
- On demo day: project local browser for live upload segment

---

## Budget Tracker

| Resource | Rate | Max Hours | Cost |
|---|---|---|---|
| B2s East US (always-on) | $0.042/hr | 240 | ~$10.00 |
| NC4as_T4_v3 East US (demo only) | $0.526/hr | 4 | ~$2.10 |
| **Total** | | | **~$12.10 of $85** |
