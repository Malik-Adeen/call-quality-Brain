---
tags: [phase-2, whisperx, gpu, pyannote, celery, docker]
date: 2026-03-28
status: complete
---

> Previous: [[07_Phase1_Postmortem]] · Next: [[09_Phase2.2_Postmortem]] · Index: [[00_Master_Dashboard]]
> See [[10_GPU_Infrastructure]] for hardware spec

## What Was Built

WhisperX large-v2 transcription task running on RTX 3060 Ti via gpu_queue.
Pyannote.audio 3.1 diarization with speaker remapping to AGENT/CUSTOMER.
Module-level model singleton — load once per worker lifetime.
VRAM sentinel check before model load. Temp file cleanup in finally block.
Dual engine database.py — AsyncSessionLocal for API, SessionLocal for workers.
Separate Dockerfile.gpu based on nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04.

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| `sqlalchemy.exc.MissingGreenlet` | Worker imported AsyncSessionLocal (asyncpg) | Added sync SessionLocal using psycopg2 |
| `ValueError: Invalid endpoint: http://cq_minio:9000` | Underscores in hostnames rejected by botocore | Renamed to `cq-minio` with hyphens, added network alias |
| PyTorch installed to Python 3.10 | CUDA base image ships Python 3.10 as default | Explicit Python 3.11 install + get-pip.py bootstrap in Dockerfile.gpu |
| numpy 1.x/2.x mismatch | pyannote pulls numpy>=2 as transitive dep | `pip install "numpy<2"` as final RUN step |
| `pynvml` import error | Package renamed | Replaced with `nvidia-ml-py` |
| PyAV build failure | Missing libav dev libraries | Added libavformat-dev, libavcodec-dev, libswresample-dev |
| Models re-downloading every cold start | `${USERPROFILE}` not expanding in Docker Desktop | Hardcoded cache paths as volume mounts |
| pyannote cached to wrong path | Uses `/root/.cache/torch/pyannote` not huggingface hub | Added second volume mount for torch cache |

## Architecture Decisions

- Separate `Dockerfile.gpu` — keeps API and worker_io images at ~500MB
- `requirements-gpu.txt` separate — GPU deps only in GPU image
- `--max-tasks-per-child=1` — forces model reload between tasks, prevents VRAM fragmentation
- Model singletons at module level: `_whisper_model` and `_diarization_pipeline`
- Speaker remapping: first speaker chronologically → AGENT, second → CUSTOMER

## Hardware Profile

- GPU: NVIDIA RTX 3060 Ti — 8GB VRAM
- CUDA: 12.1.0 · PyTorch: 2.2.0+cu121 · WhisperX: large-v2
- Cold start (first run): ~896s · Warm inference: ~33s on 15s audio

## Invariants Confirmed

- `run_whisperx` routes to `gpu_queue` exclusively
- `gpu_queue` concurrency=1, prefetch-multiplier=1
- Temp audio file deleted in finally block even on exception
- Speaker labels: AGENT or CUSTOMER — never SPEAKER_00 or SPEAKER_01
- Workers use SessionLocal (psycopg2) — never AsyncSessionLocal

## Next Phase Entry Conditions

- `docker exec cq_worker_gpu nvidia-smi` shows RTX 3060 Ti
- `torch.cuda.is_available()` returns True inside container
- Task succeeds in under 60s on warm cache
- Both cache mounts verified: huggingface/hub and torch/pyannote
