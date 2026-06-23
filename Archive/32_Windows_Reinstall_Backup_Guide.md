---
tags: [ops, backup, windows]
date: 2026-04-30
status: reference
---

# 32 — Windows Reinstall Backup Guide

> C drive will be wiped. N drive (project files) is safe.
> This document covers everything on C that will be lost and how to back it up.
> Complete all steps BEFORE starting the Windows installer.

---

## What Is Safe (N drive — do nothing)

| Path | Content |
|---|---|
| `N:\projects\call-quality-analytics\` | Full codebase, all source files |
| `N:\projects\docs\` | Entire knowledge vault |
| `N:\projects\call-quality-analytics\infra\.env` | Secrets and DB credentials |
| `N:\projects\call-quality-analytics\infra\.env.azure-worker` | Archive env |

> `.venv` is on N but rebuild it after reinstall. Never rely on venvs surviving Python version changes.

---

## What Will Be Lost (C drive) — Back These Up

### 1. HuggingFace Model Cache — CRITICAL (3–5 GB)
**Location:** `C:\Users\adeen\.cache\huggingface\`
**What's in it:** WhisperX large-v2, Pyannote.audio 3.1 models. Took hours to download. Without them the GPU worker cannot run.

**Backup:**
```
xcopy "C:\Users\adeen\.cache\huggingface" "N:\backup\huggingface_cache" /E /I /H
```

**Restore after reinstall:**
```
xcopy "N:\backup\huggingface_cache" "C:\Users\adeen\.cache\huggingface" /E /I /H
```

---

### 2. PyTorch Cache — CRITICAL (1–2 GB)
**Location:** `C:\Users\adeen\.cache\torch\`
**What's in it:** Downloaded PyTorch hub models, compiled CUDA kernels.

**Backup:**
```
xcopy "C:\Users\adeen\.cache\torch" "N:\backup\torch_cache" /E /I /H
```

---

### 3. Docker Volumes — CRITICAL (200 seeded calls + PostgreSQL data)
Docker Desktop stores all volume data on C by default. Wipe C and your seeded DB is gone.

**Option A — PostgreSQL dump (recommended, small file):**
```bash
# Run while Docker is up
docker exec cq_postgres pg_dump -U <your_db_user> <your_db_name> > N:\backup\db_dump_2026-04-30.sql
```
Replace `<your_db_user>` and `<your_db_name>` with values from `infra/.env`.

**Option B — Copy the Docker WSL VHDX (slow but complete):**
`C:\Users\adeen\AppData\Local\Docker\wsl\data\`
This preserves everything including MinIO objects. Copying it is slow (~several GB).

**Recommended: Do Option A.** The SQL dump is fast and recovers the DB. MinIO audio files in seeded data can be regenerated with `scripts/generate_test_audio.py`.

---

### 4. WSL2 Distro — IMPORTANT
WSL2 stores its Linux filesystem on C in a VHDX file. It will be wiped.

**Check your distros:**
```powershell
wsl --list --verbose
```

**Export:**
```powershell
wsl --export Ubuntu N:\backup\wsl_ubuntu_2026-04-30.tar
```

**Restore after reinstall:**
```powershell
wsl --import Ubuntu C:\WSL\Ubuntu N:\backup\wsl_ubuntu_2026-04-30.tar
```

---

### 5. SSH Keys — IMPORTANT
**Location:** `C:\Users\adeen\.ssh\`
**What's in it:** `id_rsa`, `id_rsa.pub`, `known_hosts`, `config`. Your GitHub SSH key lives here.

**Backup:**
```
xcopy "C:\Users\adeen\.ssh" "N:\backup\ssh_keys" /E /I /H
```
> Keep this folder private. Never push SSH keys to Git.

**Restore:** Copy back to `C:\Users\adeen\.ssh\` after reinstall.

---

### 6. Git Global Config
**Location:** `C:\Users\adeen\.gitconfig`

**Backup:**
```
copy "C:\Users\adeen\.gitconfig" "N:\backup\.gitconfig"
```

Or just re-run these after reinstall (faster than restoring):
```bash
git config --global user.name "Adeen"
git config --global user.email "your@email.com"
git config --global core.autocrlf true
```

---

### 7. Windows PATH (Environment Variables)
Document your current PATH before wiping — CUDA, Python, and other tools add entries here.

**Export to file:**
```powershell
[Environment]::GetEnvironmentVariable("PATH", "Machine") | Out-File N:\backup\system_path.txt
[Environment]::GetEnvironmentVariable("PATH", "User") | Out-File N:\backup\user_path.txt
```
Use as reference when setting up the new install.

---

### 8. VS Code Settings and Extensions
**Location:** `C:\Users\adeen\AppData\Roaming\Code\User\`

**Backup settings:**
```
xcopy "C:\Users\adeen\AppData\Roaming\Code\User" "N:\backup\vscode_settings" /E /I /H
```

**Export extension list:**
```powershell
code --list-extensions > N:\backup\vscode_extensions.txt
```

**Restore extensions after reinstall:**
```powershell
Get-Content N:\backup\vscode_extensions.txt | ForEach-Object { code --install-extension $_ }
```

---

### 9. pip and npm Global Config
```
copy "C:\Users\adeen\AppData\Roaming\pip\pip.ini" "N:\backup\pip.ini"
copy "C:\Users\adeen\.npmrc" "N:\backup\.npmrc"
```

---

## Post-Reinstall Checklist (do in this order)

```
[ ] Install NVIDIA GPU driver — match CUDA 12.1
[ ] Install Docker Desktop
[ ] Enable WSL2 (wsl --install) and restore distro
[ ] Install Git, restore .gitconfig, restore .ssh keys
[ ] Re-add SSH key to GitHub (Settings → SSH keys)
[ ] Install Python 3.11 explicitly, add to PATH
[ ] Install VS Code, restore settings, reinstall extensions
[ ] Restore HuggingFace cache to C:\Users\adeen\.cache\huggingface
[ ] Restore PyTorch cache to C:\Users\adeen\.cache\torch
[ ] cd N:\projects\call-quality-analytics
[ ] python -m venv .venv && .venv\Scripts\activate
[ ] pip install -r backend/requirements.txt
[ ] cd frontend && npm install
[ ] docker compose -f infra/docker-compose.yml up -d
[ ] Restore DB: docker exec -i cq_postgres psql -U <user> <db> < N:\backup\db_dump_2026-04-30.sql
[ ] Run test: upload infra/test_pipeline.wav and verify pipeline completes
```

---

## Backup Folder Structure (everything goes to N:\backup\)

```
N:\backup\
├── huggingface_cache\          (WhisperX + Pyannote models — 3-5 GB)
├── torch_cache\                (PyTorch cache — 1-2 GB)
├── wsl_ubuntu_2026-04-30.tar   (WSL2 export)
├── ssh_keys\                   (.ssh folder)
├── vscode_settings\            (VS Code user settings)
├── vscode_extensions.txt       (extension IDs)
├── db_dump_2026-04-30.sql      (PostgreSQL full dump)
├── .gitconfig
├── pip.ini
├── .npmrc
├── system_path.txt
└── user_path.txt
```

---

## Do NOT Back Up (rebuild cleanly — faster than restoring)

- `node_modules\` — run `npm install` fresh
- `.venv\` — recreate with `python -m venv .venv`
- Docker images — re-pull/rebuild from Dockerfiles
- `__pycache__\` — auto-generated
