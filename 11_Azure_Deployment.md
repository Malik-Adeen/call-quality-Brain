---
tags: [azure, deployment, demo-day]
date: 2026-04-16
status: reference
---

## Azure B2s — Always-On Demo Server

### Provision (one-time, run from local PowerShell with az cli)

```bash
az login
az group create --name callquality-rg --location eastus
az vm create \
  --resource-group callquality-rg \
  --name callquality-b2s \
  --image Ubuntu2204 \
  --size Standard_B2s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-sku Standard

az vm open-port --resource-group callquality-rg --name callquality-b2s --port 8000
az vm open-port --resource-group callquality-rg --name callquality-b2s --port 3000
az vm open-port --resource-group callquality-rg --name callquality-b2s --port 5555
```

### Initial Setup (SSH into VM once)

```bash
ssh azureuser@<PUBLIC_IP>

sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose-plugin git python3-pip

sudo usermod -aG docker azureuser
newgrp docker

git clone https://github.com/Malik-Adeen/call-quality-analytics.git
cd call-quality-analytics

cp infra/.env.example infra/.env
nano infra/.env
```

### Deploy

```bash
cd call-quality-analytics
docker compose -f infra/docker-compose.yml up -d --build
pip install psycopg2-binary bcrypt python-dotenv
python3 scripts/reset_and_seed.py
```

### Verify

```bash
docker compose -f infra/docker-compose.yml ps
curl http://localhost:8000/health
```

**Estimated cost:** Standard_B2s at ~$0.042/hr × 168hr (7 days) = ~$7.00

---

## Azure NC4as_T4_v3 — Demo Day GPU (T4 16GB)

Start exactly 20 minutes before the live pipeline demo. Stop immediately after.

### Provision

```bash
az vm create \
  --resource-group callquality-rg \
  --name callquality-t4 \
  --image Ubuntu2204 \
  --size Standard_NC4as_T4_v3 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-sku Standard
```

### GPU Setup (SSH in)

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
cp infra/.env.example infra/.env
nano infra/.env
```

### Activate GPU mode in .env

```
WHISPER_DEVICE=cuda
WHISPER_MODEL=large-v2
```

### Start and Verify

```bash
docker compose -f infra/docker-compose.yml up -d --build
docker exec cq_worker_gpu nvidia-smi
docker exec cq_worker_gpu python -c "import torch; print(torch.cuda.is_available())"
```

Upload a real .wav via dashboard and confirm pipeline completes in < 90 seconds.

### STOP IMMEDIATELY AFTER DEMO

```bash
az vm deallocate --resource-group callquality-rg --name callquality-t4
```

**Estimated cost:** Standard_NC4as_T4_v3 at $0.526/hr × 4hr = ~$2.10

---

## Budget Tracker

| Resource           | Rate       | Max Hours | Estimated Cost |
|--------------------|------------|-----------|----------------|
| B2s (always-on)    | $0.042/hr  | 168       | ~$7.00         |
| NC4as_T4_v3 (demo) | $0.526/hr  | 4         | ~$2.10         |
| **Total**          |            |           | **~$9.10 of $85** |
