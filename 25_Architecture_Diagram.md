---
tags: [architecture, diagram, reference]
date: 2026-04-17
status: reference
---

# Architecture Diagram — Hybrid Cloud System

Generated SVG diagram lives at:
`N:\projects\call-quality-analytics\docs\architecture_diagram.svg`

## What the diagram shows

- **Azure B2s (left)** — FastAPI, PostgreSQL 16, Redis 7, MinIO, worker_io, Flower
- **Local machine (right)** — worker_gpu on RTX 3060 Ti, connected to Azure via encrypted SSH tunnel
- **External LLM APIs (bottom right)** — Groq API (primary) + OpenRouter (HTTP 429/503 fallback)
- **Browser (top left)** — connects via Vite dev proxy to Azure API

## Arrow key

| Arrow | Meaning |
|---|---|
| Browser → FastAPI | REST + WebSocket via Vite proxy |
| FastAPI → PostgreSQL | Async DB reads/writes |
| FastAPI → Redis (L-path) | Task dispatch to Celery |
| Redis → worker_io | io_queue tasks (PII, scoring, WebSocket) |
| Redis ⇢ worker_gpu (dashed purple) | gpu_queue tasks via SSH tunnel |
| worker_io → Groq | LLM inference (run_groq_inference task) |
| worker_gpu → Groq | Direct LLM call from GPU worker |

## SSH tunnel ports

| Port | Service |
|---|---|
| :6379 | Redis (Celery broker) |
| :5432 | PostgreSQL (result writes) |
| :9000 | MinIO (audio file fetch) |
