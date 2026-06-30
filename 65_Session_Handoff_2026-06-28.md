---
tags:
  - handoff
  - session-starter
  - deployment
date: '2026-06-28'
status: active
---

# 65 — Session Handoff (2026-06-28) — Public URL + Startup Automation Fixed

> Load CONTEXT.md + INVARIANTS.md + this file at session start.
> Supersedes 63_Session_Handoff_2026-06-25.md.

---

## Current Repo State

- **Active branch:** `deploy/fahad-demo`
- **Master branch:** clean, untouched
- **Alembic head:** `20260621_idempotency_constraints` (uq_calls_tenant_audio_path removed)
- **Public URL:** `https://deltaroot-pt-lp.tailb8d983.ts.net/` (Tailscale Funnel — permanent)

---

## What Was Done This Session (2026-06-28)

### Problem
Site was unreachable at `callquality.giize.com` after reboot. Dynu DDNS was pointing at
the correct public IP (74.14.137.225) but GL-iNet router had no port 80 forward rule.
Attempted port forwarding — blocked by double NAT complexity and Docker Desktop conflict
with netsh portproxy on port 80.

### Solution: Tailscale Funnel
Replaced Dynu DDNS + port forwarding entirely with Tailscale Funnel.
- Outbound-only connection — no router config, no NAT, no ISP blocking
- Fixed HTTPS URL tied to machine name, not IP
- Free tier, permanent

### Changes Made

**1. Tailscale Funnel enabled as background service**
```bash
tailscale.exe funnel --bg 80
```
Registered with Tailscale Windows service — survives reboots automatically.

**2. CORS updated in `infra/.env.prod`**
CORS_ORIGINS=https://deltaroot-pt-lp.tailb8d983.ts.net

**3. sudoers configured for passwordless docker/service**
fahad ALL=(ALL) NOPASSWD: /usr/sbin/service, /usr/bin/docker
File: `/etc/sudoers.d/callquality`

**4. Startup script created**
Path: `C:\Users\fahad\Desktop\start-callquality.ps1`
```powershell
Write-Host "Starting CallQuality services..." -ForegroundColor Cyan
Write-Host "Starting SSH..."
wsl -e sudo service ssh start
Start-Sleep -Seconds 15
Write-Host "Starting core containers..."
wsl -e bash -c "cd /mnt/c/Users/fahad/call-qualtiy/call-quality-analytics && sudo docker compose -f infra/docker-compose.app.yml --env-file infra/.env.prod up -d --no-recreate"
Start-Sleep -Seconds 30
Write-Host "Force-recreating nginx..."
wsl -e bash -c "cd /mnt/c/Users/fahad/call-qualtiy/call-quality-analytics && sudo docker compose -f infra/docker-compose.app.yml --env-file infra/.env.prod up -d --force-recreate nginx"
Start-Sleep -Seconds 5
Write-Host "Reloading nginx config..."
wsl -e sudo docker exec cq_nginx nginx -s reload
Write-Host "Done! Site live at: https://deltaroot-pt-lp.tailb8d983.ts.net/" -ForegroundColor Green
```

**5. Task Scheduler registered**
Task name: `CallQuality-Startup`
Trigger: AtLogOn, 2-minute delay (PT2M)
Runs as: fahad, elevated (Highest)

**Key lessons learned this session:**
- `netsh portproxy` on port 80 conflicts with Docker Desktop's own port forwarding — delete it
- nginx must be `--force-recreate` after reboot, not just reloaded — WSL2 bind mount paths
  go stale and `docker start` fails with mount error
- Tailscale Funnel is the correct solution for this setup — Cloudflare named tunnel requires
  owning the root domain, which is impossible with a Dynu subdomain
- `tailscale.exe` (with .exe suffix) is callable from WSL2 via Windows interop

---

## Infrastructure State

| Component | Status | Persistence |
|---|---|---|
| Docker stack | ✅ Running | Task Scheduler at login + 2min delay |
| SSH (WSL2) | ✅ Running | Task Scheduler at login |
| nginx | ✅ Running | Force-recreated on every startup |
| Tailscale Funnel | ✅ Background | Tailscale Windows service (automatic) |
| Public URL | `https://deltaroot-pt-lp.tailb8d983.ts.net/` | Fixed permanently |
| Dynu DDNS | ❌ Retired | Uninstall client from Fahad's machine |

---

## Deployment Survival Guide (Updated)

After any reboot, the Task Scheduler fires automatically after 2 minutes.
If it fails for any reason, run manually:
```powershell
powershell.exe -ExecutionPolicy Bypass -File "$env:USERPROFILE\Desktop\start-callquality.ps1"
```

If nginx still fails to start:
```bash
sudo docker compose -f infra/docker-compose.app.yml --env-file infra/.env.prod up -d --force-recreate nginx
```

If login fails after nginx is up — nginx DNS cache stale:
```bash
sudo docker exec cq_nginx nginx -s reload
```

Remote SSH access: `ssh fahad@100.118.221.10` (Tailscale IP, persists across reboots
via Task Scheduler script starting SSH automatically)

---

## Known Issues (Post-Demo, Pre-First Customer)

| Issue | Severity | Notes |
|---|---|---|
| dedup constraint removed | HIGH | Same file creates multiple Call rows — re-evaluate before first customer |
| auth.py RLS bypass broad | MEDIUM | `platform_bypass=true` for entire login flow, should scope to user lookup only |
| infra/.env not gitignored | HIGH | Contains live secrets — verify .gitignore |
| Groq key in both .env files | MEDIUM | `.env` silently overrides `.env.prod` — keep in sync manually |
| reset_and_seed.py hardcodes localhost | LOW | Run with DATABASE_URL override |
| Dynu DDNS client | LOW | Still installed on Fahad's machine — uninstall |

---

## Next Session Starting Point

1. ROI reporting module (Phase 10)
2. Agentic AI assistant (NL query over PostgreSQL) — after ROI
3. Post-demo: evaluate OVHcloud Beauharnois + RunPod GPU for production
4. Retire Dynu DDNS client from Fahad's machine (5 minutes, low priority)

---

## Seeded Accounts

| Email | Password | Role |
|---|---|---|
| admin@callquality.demo | admin1234 | TENANT_ADMIN |
| supervisor@callquality.demo | supervisor1234 | SUPERVISOR |
| viewer@callquality.demo | viewer1234 | VIEWER |
| platform@callquality.internal | platform1234 | PLATFORM_ADMIN |
