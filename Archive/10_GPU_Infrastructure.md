---
tags: [infrastructure, gpu, docker, cuda, windows]
date: 2026-03-28
status: reference
---

## Host Environment

| Property     | Value                              |
| ------------ | ---------------------------------- |
| OS           | Windows + Docker Desktop + WSL2    |
| CPU          | AMD Ryzen 5 3600                   |
| GPU          | NVIDIA GeForce RTX 3060 Ti         |
| VRAM         | 8GB                                |
| CUDA Version | 12.1.0                             |
| Driver       | Current as of March 2026           |
| Project Path | N:\projects\call-quality-analytics |

## Dockerfile.gpu Base Image
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04

Note: This image is deprecated by NVIDIA. Functional for demo lifetime.
Do not upgrade base image without updating PyTorch cu121 index URL to match.

## Python Version Disambiguation

The CUDA base image ships Python 3.10 as system default.
Python 3.11 must be explicitly installed and set as default:
apt-get install python3.11 python3.11-dev python3.11-distutils
update-alternatives --install /usr/local/bin/python python /usr/bin/python3.11 1
curl https://bootstrap.pypa.io/get-pip.py | python3.11

## PyTorch Installation

Always install PyTorch before other requirements to ensure CUDA variant is used:
pip install torch==2.2.0+cu121 torchaudio==2.2.0+cu121 
--index-url https://download.pytorch.org/whl/cu121

cu121 must match the CUDA base image version exactly.

## numpy Version Pinning

pyannote.audio pulls numpy>=2 as a transitive dependency.
numpy 2.x breaks WhisperX and faster-whisper.
Always install numpy<2 as the FINAL pip step in Dockerfile.gpu:
RUN pip install "numpy<2"

## Cache Volume Mounts

| Cache            | Host Path                           | Container Path             |
| ---------------- | ----------------------------------- | -------------------------- |
| HuggingFace Hub  | `C:\Users\adeen\.cache\huggingface` | `/root/.cache/huggingface` |
| Torch / Pyannote | `C:\Users\adeen\.cache\torch`       | `/root/.cache/torch`       |

Critical: pyannote caches to `/root/.cache/torch/pyannote` not to the
HuggingFace hub directory. Both mounts are required.

## MinIO Hostname Rule

botocore enforces RFC hostname validation. Underscores in hostnames are
rejected with `ValueError: Invalid endpoint`.

Container name `cq_minio` (underscores) cannot be used as an endpoint hostname.
Solution: set `hostname: cq-minio` and add network alias `cq-minio` in compose.
All MINIO_ENDPOINT values must use `cq-minio:9000` — never `cq_minio:9000`.

## VRAM Budget

| Model                            | VRAM Usage        |
| -------------------------------- | ----------------- |
| WhisperX large-v2                | ~3GB              |
| Pyannote speaker-diarization-3.1 | ~1GB              |
| Combined peak                    | ~4-5GB            |
| Available headroom               | ~3GB              |
| VRAM sentinel threshold          | 2GB free required |

## GPU Activation for Azure Demo Day

In `infra/docker-compose.yml` worker_gpu service, the deploy block is
already active. In `.env`:
WHISPER_DEVICE=cuda
WHISPER_MODEL=large-v2

For Azure NC4as_T4_v3 (NVIDIA T4 16GB):
- Start VM exactly 20 minutes before live demo
- Stop and deallocate immediately after demo
- Estimated cost: ~$2 for 4 hours

## Package Names Reference

| Wrong                                 | Correct         |
| ------------------------------------- | --------------- |
| `pynvml`                              | `nvidia-ml-py`  |
| `postgres://` in worker env           | `postgresql://` |
| `postgresql+asyncpg://` in worker env | `postgresql://` |
| `cq_minio` as endpoint                | `cq-minio`      |