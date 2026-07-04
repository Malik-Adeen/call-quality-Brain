# 66 — Codebase Audit Snapshot
**Date:** 2026-06-30  
**Branch:** master  
**Auditor:** Claude Code (claude-sonnet-4-6)

---

## 1. Repo Tree

### backend/ (Python files with line counts)

```
backend/
├── alembic/
│   ├── env.py                                    [108 lines]
│   └── versions/
│       ├── 20260501_base_schema.py               [180 lines]
│       └── 20260621_idempotency_constraints.py   [ 47 lines]
├── app/
│   ├── __init__.py                               [  0 lines]
│   ├── auth/
│   │   ├── __init__.py                           [  0 lines]
│   │   ├── dependencies.py                       [ 53 lines]
│   │   └── jwt.py                                [ 26 lines]
│   ├── celery_app.py                             [ 42 lines]
│   ├── config.py                                 [ 28 lines]
│   ├── database.py                               [ 72 lines]
│   ├── limiter.py                                [  4 lines]
│   ├── main.py                                   [ 66 lines]
│   ├── models/
│   │   ├── __init__.py                           [  0 lines]
│   │   └── orm.py                                [120 lines]
│   ├── pipeline/
│   │   ├── __init__.py                           [  0 lines]
│   │   └── tasks.py                              [547 lines]
│   ├── routers/
│   │   ├── __init__.py                           [  0 lines]
│   │   ├── agents.py                             [499 lines]
│   │   ├── auth.py                               [139 lines]
│   │   ├── calls.py                              [477 lines]
│   │   ├── minio_event.py                        [127 lines]
│   │   ├── platform.py                           [539 lines]
│   │   ├── reports.py                            [200 lines]
│   │   ├── users.py                              [173 lines]
│   │   └── ws.py                                 [ 90 lines]
│   ├── schemas/
│   │   ├── __init__.py                           [  0 lines]
│   │   └── api.py                                [117 lines]
│   └── services/
│       ├── __init__.py                           [  0 lines]
│       ├── llm_client.py                         [180 lines]
│       ├── minio_client.py                       [ 46 lines]
│       ├── presidio_service.py                   [ 80 lines]
│       └── whisper_service.py                    [ 96 lines]
├── tests/
│   ├── conftest.py                               [ 91 lines]
│   ├── test_auth.py                              [130 lines]
│   ├── test_minio_event.py                       [104 lines]
│   ├── test_pipeline.py                          [104 lines]
│   └── test_scoring.py                           [103 lines]
├── alembic.ini
├── Dockerfile
├── Dockerfile.cpu
├── Dockerfile.gpu
├── Dockerfile.gpu.blackwell
├── en_core_web_lg-3.8.0-py3-none-any.whl
├── pytest.ini
├── requirements.txt
└── requirements-gpu.txt
```

### frontend/src/ (TypeScript/TSX files with line counts)

```
frontend/src/
├── api/
│   └── client.ts                                 [ 27 lines]
├── App.tsx                                       [196 lines]
├── components/
│   ├── CallDetailPanel.tsx                       [446 lines]
│   └── Sidebar.tsx                               [156 lines]
├── main.tsx                                      [ 12 lines]
├── pages/
│   ├── AgentManagement.tsx                       [371 lines]
│   ├── Agents.tsx                                [401 lines]
│   ├── CallDetail.tsx                            [ 18 lines]
│   ├── CallList.tsx                              [204 lines]
│   ├── CallMonitor.tsx                           [283 lines]
│   ├── Login.tsx                                 [137 lines]
│   ├── Overview.tsx                              [632 lines]
│   ├── PlatformOverview.tsx                      [327 lines]
│   ├── Register.tsx                              [206 lines]
│   ├── Reports.tsx                               [195 lines]
│   ├── SystemHealth.tsx                          [244 lines]
│   ├── TenantManagement.tsx                      [266 lines]
│   ├── UploadCall.tsx                            [239 lines]
│   ├── UsageAnalytics.tsx                        [224 lines]
│   └── UserManagement.tsx                        [335 lines]
├── store/
│   ├── auth.ts                                   [ 33 lines]
│   └── ws.ts                                     [ 16 lines]
├── types/
│   └── api.ts                                    [200 lines]
└── utils/
    ├── dashboardTransforms.ts                    [236 lines]
    └── format.ts                                 [ 29 lines]
```

### infra/

```
infra/
├── .env                                          [present, 26 lines — secrets omitted]
├── .env.example
├── .env.gpu.example
├── .env.prod                                     [present, 31 lines — secrets omitted]
├── docker-compose.app.yml
├── docker-compose.azure.yml
├── docker-compose.gpu.yml
├── docker-compose.hybrid.yml
├── docker-compose.prod.yml
├── docker-compose.yml
├── nginx.conf
├── nsg-runbook.sh
├── test_call.wav
└── test_pipeline.wav
```

### scripts/ (Python files with line counts)

```
scripts/
├── build_graph.py                                [527 lines]
├── fix_white_bg.py                               [ 64 lines]
├── generate_test_audio.py                        [112 lines]
├── merge_test_audio.py                           [ 75 lines]
├── migrate_colors.py                             [242 lines]
├── migrate_height.py                             [ 54 lines]
├── preflight_fetcher.py                          [ 80 lines]
├── reset_and_seed.py                             [262 lines]
├── seed_data.py                                  [605 lines]
└── tunnel.bat
```

### alembic/versions/ (under backend/)

```
backend/alembic/versions/
├── 20260501_base_schema.py                       [180 lines]
└── 20260621_idempotency_constraints.py           [ 47 lines]
```

Alembic head: `20260621_idempotency_constraints`. Two migrations total (squashed); fresh DB builds with one `alembic upgrade head`.

---

## 2. Dependency Manifests

### backend/requirements.txt

```
fastapi
uvicorn[standard]
sqlalchemy[asyncio]
alembic
asyncpg
psycopg2-binary
celery[redis]
redis
boto3
PyJWT[crypto]>=2.8.0
bcrypt
pydantic[email]
pydantic-settings
python-multipart
httpx
python-dotenv
presidio-analyzer
presidio-anonymizer
playwright
rapidfuzz
slowapi
```

### backend/requirements-gpu.txt

```
torch
torchaudio
whisperx
pyannote.audio==3.1.1
faster-whisper
ctranslate2
nvidia-ml-py
matplotlib
```

### backend/requirements-cpu.txt

[absent]

### frontend/package.json

```json
{
  "name": "frontend",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "lint": "eslint .",
    "preview": "vite preview"
  },
  "dependencies": {
    "@tailwindcss/vite": "^4.2.2",
    "axios": "^1.15.0",
    "lucide-react": "^1.8.0",
    "motion": "^12.40.0",
    "react": "^19.2.4",
    "react-dom": "^19.2.4",
    "react-router-dom": "^7.14.0",
    "recharts": "^3.8.1",
    "tailwindcss": "^4.2.2",
    "zustand": "^5.0.12"
  },
  "devDependencies": {
    "@eslint/js": "^9.39.4",
    "@types/node": "^24.12.2",
    "@types/react": "^19.2.14",
    "@types/react-dom": "^19.2.3",
    "@vitejs/plugin-react": "^6.0.1",
    "eslint": "^9.39.4",
    "eslint-plugin-react-hooks": "^7.0.1",
    "eslint-plugin-react-refresh": "^0.5.2",
    "globals": "^17.4.0",
    "typescript": "~6.0.2",
    "typescript-eslint": "^8.58.0",
    "vite": "^8.0.4"
  },
  "overrides": {
    "immer": ">=11.0.1"
  }
}
```

### pyproject.toml

[absent]

---

## 3. Docker & Infra

### backend/Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN groupadd --system appgroup && useradd --system --gid appgroup appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN python -m spacy download en_core_web_lg

ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
RUN playwright install chromium --with-deps && chmod -R 755 /opt/ms-playwright

COPY . .

RUN chown -R appuser:appgroup /app
USER appuser

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

### backend/Dockerfile.cpu

```dockerfile
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    curl \
    build-essential \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir \
    torch==2.2.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cpu

RUN pip install --no-cache-dir -r requirements.txt

RUN pip install --no-cache-dir \
    whisperx \
    "pyannote.audio==3.1.1" \
    faster-whisper \
    ctranslate2

RUN pip install --no-cache-dir "numpy<2"

RUN python -m spacy download en_core_web_lg

COPY . .

CMD ["celery", "-A", "app.celery_app", "worker", "-Q", "gpu_queue", \
     "--loglevel=info", "--concurrency=1", "--prefetch-multiplier=1", \
     "--max-tasks-per-child=1", "--hostname=worker_cpu@%h"]
```

### backend/Dockerfile.gpu

```dockerfile
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PATH="/usr/local/bin:$PATH"

RUN apt-get update && apt-get install -y \
    python3.11 python3.11-dev python3-pip python3.11-distutils \
    ffmpeg curl pkg-config \
    libavformat-dev libavcodec-dev libavdevice-dev \
    libavutil-dev libavfilter-dev libswscale-dev libswresample-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 \
    && update-alternatives --install /usr/local/bin/python python /usr/bin/python3.11 1 \
    && update-alternatives --install /usr/local/bin/pip pip /usr/local/bin/pip3.11 1

WORKDIR /app

COPY requirements.txt .
COPY requirements-gpu.txt .

RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir torch==2.2.0+cu121 torchaudio==2.2.0+cu121 \
       --index-url https://download.pytorch.org/whl/cu121 \
    && python -m pip install --no-cache-dir -r requirements.txt \
    && python -m pip install --no-cache-dir -r requirements-gpu.txt \
    && python -m pip install --no-cache-dir "numpy<2"

COPY . .

CMD ["celery", "-A", "app.celery_app", "worker", "--queues=gpu_queue", \
     "--concurrency=1", "--prefetch-multiplier=1", "--loglevel=info"]
```

### backend/Dockerfile.gpu.blackwell

```dockerfile
FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PATH="/usr/local/bin:$PATH"

RUN apt-get update && apt-get install -y \
    python3.11 python3.11-dev python3-pip python3.11-distutils \
    ffmpeg curl pkg-config \
    libavformat-dev libavcodec-dev libavdevice-dev \
    libavutil-dev libavfilter-dev libswscale-dev libswresample-dev \
    git cmake build-essential libopenblas-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 \
    && update-alternatives --install /usr/local/bin/python python /usr/bin/python3.11 1 \
    && update-alternatives --install /usr/local/bin/pip pip /usr/local/bin/pip3.11 1

WORKDIR /app

COPY requirements.txt .
COPY requirements-gpu.txt .

RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir torch==2.7.0+cu128 torchaudio==2.7.0+cu128 \
       --index-url https://download.pytorch.org/whl/cu128 \
    && python -m pip install --no-cache-dir ctranslate2>=4.4.0 \
    && python -m pip install --no-cache-dir -r requirements.txt \
    && python -m pip install --no-cache-dir -r requirements-gpu.txt \
    && python -m pip install --no-cache-dir "numpy<2"

COPY en_core_web_lg-3.8.0-py3-none-any.whl .
RUN pip install --no-cache-dir en_core_web_lg-3.8.0-py3-none-any.whl \
    && rm en_core_web_lg-3.8.0-py3-none-any.whl

COPY . .

CMD ["celery", "-A", "app.celery_app", "worker", "--queues=gpu_queue", \
     "--concurrency=1", "--prefetch-multiplier=1", "--loglevel=info"]
```

### infra/docker-compose.yml (local dev — all-in-one)

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: cq_postgres
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "127.0.0.1:5432:5432"
    networks:
      - cq_network
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:${REDIS_IMAGE_TAG:-7.4.2-alpine}
    container_name: cq_redis
    restart: always
    command: redis-server --appendonly yes --appendfsync everysec --requirepass ${REDIS_PASSWORD}
    ports:
      - "127.0.0.1:6379:6379"
    networks:
      - cq_network

  minio:
    image: minio/minio:${MINIO_IMAGE_TAG:-RELEASE.2025-12-20T10-18-58Z}
    container_name: cq_minio
    hostname: cq-minio
    restart: always
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
      MINIO_NOTIFY_WEBHOOK_ENABLE_PRIMARY: "on"
      MINIO_NOTIFY_WEBHOOK_ENDPOINT_PRIMARY: "http://cq-api:8000/internal/minio-event"
      MINIO_NOTIFY_WEBHOOK_AUTH_TOKEN_PRIMARY: "${MINIO_WEBHOOK_SECRET}"
      MINIO_NOTIFY_WEBHOOK_QUEUE_DIR_PRIMARY: "/data/.webhook-queue"
      MINIO_NOTIFY_WEBHOOK_QUEUE_LIMIT_PRIMARY: "10000"
    ports:
      - "127.0.0.1:9000:9000"
      - "127.0.0.1:9001:9001"
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data
    networks:
      cq_network:
        aliases:
          - cq-minio

  minio_init:
    image: minio/minio:${MINIO_IMAGE_TAG:-RELEASE.2025-12-20T10-18-58Z}
    container_name: cq_minio_init
    restart: on-failure
    depends_on:
      - minio
    networks:
      - cq_network
    volumes:
      - ./test_pipeline.wav:/tmp/test_pipeline.wav:ro
    entrypoint: >
      /bin/sh -c "
      until mc alias set local http://cq-minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} >/dev/null 2>&1; do sleep 1; done;
      mc mb --ignore-existing local/audio-uploads;
      mc anonymous set none local/audio-uploads;
      mc cp /tmp/test_pipeline.wav local/audio-uploads/test_pipeline.wav;
      mc event add --ignore-existing --event put local/audio-uploads arn:minio:sqs::PRIMARY:webhook;
      mc event list local/audio-uploads;
      "

  api:
    build:
      context: ../backend
      dockerfile: Dockerfile
    container_name: cq_api
    restart: unless-stopped
    env_file: .env
    environment:
      DATABASE_URL: postgresql+asyncpg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@cq_postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://:${REDIS_PASSWORD}@cq_redis:6379/0
      MINIO_ENDPOINT: cq-minio:9000
      MINIO_ACCESS_KEY: ${MINIO_ROOT_USER}
      MINIO_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
      MINIO_BUCKET: audio-uploads
      MINIO_WEBHOOK_SECRET: ${MINIO_WEBHOOK_SECRET}
      PLAYWRIGHT_BROWSERS_PATH: /opt/ms-playwright
      CORS_ORIGINS: ${CORS_ORIGINS:-http://localhost:5173}
    ports:
      - "8000:8000"
    networks:
      cq_network:
        aliases:
          - cq-api
    depends_on:
      postgres:
        condition: service_started
      redis:
        condition: service_started
      minio:
        condition: service_started

  worker_io:
    build:
      context: ../backend
      dockerfile: Dockerfile
    container_name: cq_worker_io
    restart: unless-stopped
    command: >
      celery -A app.celery_app worker --queues=io_queue --concurrency=4 --prefetch-multiplier=2 --loglevel=info --hostname=worker_io@%h
    env_file: .env
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@cq_postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://:${REDIS_PASSWORD}@cq_redis:6379/0
      MINIO_ENDPOINT: cq-minio:9000
      MINIO_ACCESS_KEY: ${MINIO_ROOT_USER}
      MINIO_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
      MINIO_BUCKET: audio-uploads
    networks:
      - cq_network
    depends_on:
      postgres:
        condition: service_started
      redis:
        condition: service_started

  worker_gpu:
    build:
      context: ../backend
      dockerfile: Dockerfile.gpu
    container_name: cq_worker_gpu
    restart: unless-stopped
    command: celery -A app.celery_app worker -Q gpu_queue --loglevel=info --concurrency=1 --prefetch-multiplier=1 --max-tasks-per-child=1
    volumes:
      - ${MODEL_CACHE_HF}:/root/.cache/huggingface
      - ${MODEL_CACHE_TORCH}:/root/.cache/torch
    environment:
      - DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@cq_postgres:5432/${POSTGRES_DB}
      - REDIS_URL=redis://:${REDIS_PASSWORD}@cq_redis:6379/0
      - HF_TOKEN=${HF_TOKEN}
      - WHISPER_DEVICE=cuda
      - WHISPER_MODEL=${WHISPER_MODEL}
      - MINIO_ENDPOINT=cq-minio:9000
      - MINIO_ACCESS_KEY=${MINIO_ROOT_USER}
      - MINIO_SECRET_KEY=${MINIO_ROOT_PASSWORD}
      - MINIO_BUCKET=audio-uploads
      - GROQ_API_KEY=${GROQ_API_KEY}
      - OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
      - JWT_SECRET=${JWT_SECRET}
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    depends_on:
      - redis
      - postgres
      - minio
    networks:
      - cq_network

  flower:
    image: mher/flower:2.0
    container_name: cq_flower
    restart: unless-stopped
    command: >
      celery --broker=redis://:${REDIS_PASSWORD}@cq_redis:6379/0 flower --port=5555 --basic_auth=${FLOWER_USER}:${FLOWER_PASSWORD}
    ports:
      - "127.0.0.1:5555:5555"
    networks:
      - cq_network
    depends_on:
      - redis

networks:
  cq_network:
    driver: bridge

volumes:
  postgres_data:
  minio_data:
```

### infra/docker-compose.app.yml (B4ms app tier)

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: cq_postgres
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "5433:5432"      # NOTE: host port 5433, not 5432
    networks:
      - cq_network
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7.4.2-alpine
    container_name: cq_redis
    restart: always
    command: redis-server --appendonly yes --appendfsync everysec --requirepass ${REDIS_PASSWORD}
    ports:
      - "6379:6379"
    networks:
      - cq_network

  minio:
    image: minio/minio:${MINIO_IMAGE_TAG}
    container_name: cq_minio
    hostname: cq-minio
    restart: always
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
      MINIO_NOTIFY_WEBHOOK_ENABLE_PRIMARY: "on"
      MINIO_NOTIFY_WEBHOOK_ENDPOINT_PRIMARY: "http://cq-api:8000/internal/minio-event"
      MINIO_NOTIFY_WEBHOOK_AUTH_TOKEN_PRIMARY: "${MINIO_WEBHOOK_SECRET}"
      MINIO_NOTIFY_WEBHOOK_QUEUE_DIR_PRIMARY: "/data/.webhook-queue"
      MINIO_NOTIFY_WEBHOOK_QUEUE_LIMIT_PRIMARY: "10000"
    ports:
      - "9000:9000"      # NOTE: bound 0.0.0.0 (NSG must restrict)
      - "127.0.0.1:9001:9001"
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data
    networks:
      cq_network:
        aliases:
          - cq-minio

  minio_init:
    image: minio/mc:${MINIO_IMAGE_TAG}
    container_name: cq_minio_init
    restart: on-failure
    depends_on:
      - minio
    networks:
      - cq_network
    entrypoint: >
      /bin/sh -c "
      until mc alias set local http://cq-minio:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD} >/dev/null 2>&1; do sleep 1; done;
      mc mb --ignore-existing local/audio-uploads;
      mc anonymous set none local/audio-uploads;
      mc event add --ignore-existing --event put local/audio-uploads arn:minio:sqs::PRIMARY:webhook;
      mc event list local/audio-uploads;
      "

  api:
    build:
      context: ../backend
      dockerfile: Dockerfile
    container_name: cq_api
    restart: unless-stopped
    env_file: .env
    environment:
      DATABASE_URL: postgresql+asyncpg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@cq_postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://:${REDIS_PASSWORD}@cq_redis:6379/0
      MINIO_ENDPOINT: cq-minio:9000
      MINIO_ACCESS_KEY: ${MINIO_ROOT_USER}
      MINIO_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
      MINIO_BUCKET: audio-uploads
      MINIO_WEBHOOK_SECRET: ${MINIO_WEBHOOK_SECRET}
      PLAYWRIGHT_BROWSERS_PATH: /opt/ms-playwright
      CORS_ORIGINS: ${CORS_ORIGINS}
    ports:
      - "127.0.0.1:8000:8000"
    networks:
      cq_network:
        aliases:
          - cq-api
    depends_on:
      postgres:
        condition: service_started
      redis:
        condition: service_started
      minio:
        condition: service_started

  worker_io:
    build:
      context: ../backend
      dockerfile: Dockerfile
    container_name: cq_worker_io
    restart: unless-stopped
    command: >
      celery -A app.celery_app worker --queues=io_queue --concurrency=4
      --prefetch-multiplier=2 --loglevel=info --hostname=worker_io@%h
    env_file: .env
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@cq_postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://:${REDIS_PASSWORD}@cq_redis:6379/0
      MINIO_ENDPOINT: cq-minio:9000
      MINIO_ACCESS_KEY: ${MINIO_ROOT_USER}
      MINIO_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
      MINIO_BUCKET: audio-uploads
    networks:
      - cq_network
    depends_on:
      postgres:
        condition: service_started
      redis:
        condition: service_started

  nginx:
    build:
      context: ../frontend
      dockerfile: Dockerfile
    container_name: cq_nginx
    restart: unless-stopped
    ports:
      - "0.0.0.0:80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - api
    networks:
      - cq_network

  flower:
    image: mher/flower:2.0
    container_name: cq_flower
    restart: unless-stopped
    command: >
      celery --broker=redis://:${REDIS_PASSWORD}@cq_redis:6379/0
      flower --port=5555 --basic_auth=${FLOWER_USER}:${FLOWER_PASSWORD}
    ports:
      - "127.0.0.1:5555:5555"
    networks:
      - cq_network
    depends_on:
      - redis

networks:
  cq_network:
    driver: bridge

volumes:
  postgres_data:
  minio_data:
```

### infra/docker-compose.gpu.yml (NC4as_T4_v3 GPU tier)

```yaml
services:
  worker_cpu:
    build:
      context: ../backend
      dockerfile: Dockerfile.gpu
    container_name: cq_worker_gpu
    restart: unless-stopped
    command: >
      celery -A app.celery_app worker -Q gpu_queue --loglevel=info
      --concurrency=1 --prefetch-multiplier=1 --max-tasks-per-child=1
      --hostname=worker_cpu@%h
    volumes:
      - ${MODEL_CACHE_HF:-/data/models/huggingface}:/root/.cache/huggingface
      - ${MODEL_CACHE_TORCH:-/data/models/torch}:/root/.cache/torch
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${APP_TIER_HOST}:5432/${POSTGRES_DB}
      REDIS_URL: redis://:${REDIS_PASSWORD}@${APP_TIER_HOST}:6379/0
      HF_TOKEN: ${HF_TOKEN}
      WHISPER_DEVICE: cuda
      WHISPER_MODEL: large-v2
      MINIO_ENDPOINT: ${APP_TIER_HOST}:9000
      MINIO_ACCESS_KEY: ${MINIO_ROOT_USER}
      MINIO_SECRET_KEY: ${MINIO_ROOT_PASSWORD}
      MINIO_BUCKET: audio-uploads
      GROQ_API_KEY: ${GROQ_API_KEY}
      OPENROUTER_API_KEY: ${OPENROUTER_API_KEY}
      JWT_SECRET: ${JWT_SECRET}
    env_file: .env
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

### infra/docker-compose.azure.yml (single-host Azure, CPU worker)

Full content: single-machine Azure variant with `worker_cpu` using `Dockerfile.cpu` on `gpu_queue`, all services on `cq_network`. Ports 5432/6379/9000 bound to `127.0.0.1`. 193 lines.

### infra/docker-compose.hybrid.yml (Windows dev — local services + Docker GPU)

Hardcodes Windows paths (`C:\Users\adeen\.cache\...`) and `host.docker.internal`. Dev-only; no REDIS_PASSWORD. 45 lines.

### infra/docker-compose.prod.yml (production — nginx included)

Full prod compose: all 5 services + nginx. GPU worker uses `Dockerfile.gpu`. Postgres/Redis/Minio have no exposed ports (internal-only). `ports: "80:80"` on nginx. `env_file: .env.prod`. 185 lines.

### infra/nginx.conf

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    server_tokens off;

    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/javascript application/javascript
               application/json application/xml image/svg+xml;

    location /api/ {
        proxy_pass http://cq-api:8000/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
        proxy_connect_timeout 10s;
    }

    location /ws/ {
        proxy_pass http://cq-api:8000/ws/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

---

## 4. Invariant-Critical Source Files

### backend/app/main.py

```python
import asyncio
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.config import settings
from app.limiter import limiter
from app.routers import auth, calls, agents, reports, ws, platform, users
from app.routers.minio_event import router as minio_event_router
from app.routers.ws import redis_subscriber


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(redis_subscriber())
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


app = FastAPI(title="Call Quality Analytics API", version="1.0.0", lifespan=lifespan, docs_url=None, redoc_url=None)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

_cors_origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(calls.router, prefix="/calls", tags=["calls"])
app.include_router(agents.router, prefix="/agents", tags=["agents"])
app.include_router(users.router, prefix="/users", tags=["users"])
app.include_router(reports.router, prefix="/reports", tags=["reports"])
app.include_router(ws.router, tags=["websocket"])
app.include_router(platform.router, prefix="/platform", tags=["platform"])
app.include_router(minio_event_router, prefix="/internal", tags=["internal"])


@app.middleware("http")
async def inject_request_id(request: Request, call_next):
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response


@app.get("/health")
async def health():
    return {"status": "ok"}
```

### backend/app/database.py

```python
from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from app.config import settings


def build_async_url(url: str) -> str:
    url = url.replace("postgresql+asyncpg://", "postgresql://")
    return url.replace("postgresql://", "postgresql+asyncpg://", 1)


def build_sync_url(url: str) -> str:
    return url.replace("postgresql+asyncpg://", "postgresql://")


async_engine = create_async_engine(
    build_async_url(settings.database_url),
    echo=False,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10,
)

sync_engine = create_engine(
    build_sync_url(settings.database_url),
    echo=False,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10,
)

AsyncSessionLocal = async_sessionmaker(
    async_engine,
    expire_on_commit=False,
    class_=AsyncSession,
)

SessionLocal = sessionmaker(
    bind=sync_engine,
    autocommit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with AsyncSessionLocal() as session:
        yield session


async def get_db_with_tenant(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    tenant_id = getattr(request.state, "tenant_id", None)
    if tenant_id is not None and tenant_id != "":
        await db.execute(
            text("SELECT set_config('app.current_tenant', :tid, true)"),
            {"tid": str(tenant_id)},
        )
    yield db


async def get_db_platform():
    async with AsyncSessionLocal() as session:
        async with session.begin():
            await session.execute(text("SET LOCAL app.platform_bypass = 'true'"))
            yield session
```

### backend/app/celery_app.py

```python
import socket
from celery import Celery
from app.config import settings

celery_app = Celery(
    "callquality",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=["app.pipeline.tasks"],
)

celery_app.conf.task_routes = {
    "pipeline.tasks.run_whisperx":           {"queue": "gpu_queue"},
    "pipeline.tasks.redact_pii":             {"queue": "io_queue"},
    "pipeline.tasks.extract_agent_identity": {"queue": "io_queue"},
    "pipeline.tasks.compute_talk_balance":   {"queue": "io_queue"},
    "pipeline.tasks.run_groq_inference":     {"queue": "io_queue"},
    "pipeline.tasks.write_scores":           {"queue": "io_queue"},
    "pipeline.tasks.notify_websocket":       {"queue": "io_queue"},
}

celery_app.conf.task_serializer = "json"
celery_app.conf.result_serializer = "json"
celery_app.conf.accept_content = ["json"]
celery_app.conf.timezone = "UTC"
celery_app.conf.enable_utc = True
celery_app.conf.result_expires = 300

celery_app.conf.broker_connection_timeout = 30.0
celery_app.conf.broker_connection_retry_on_startup = True
celery_app.conf.broker_pool_limit = 10
celery_app.conf.task_acks_late = True
celery_app.conf.task_reject_on_worker_lost = True
celery_app.conf.broker_transport_options = {
    "visibility_timeout": 3600,
    "socket_keepalive": True,
    "socket_keepalive_options": {
        socket.TCP_KEEPIDLE:  60,
        socket.TCP_KEEPINTVL: 15,
        socket.TCP_KEEPCNT:   3,
    },
}
```

### backend/app/auth/dependencies.py

```python
import os
import uuid
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.orm import User
from app.auth.jwt import decode_access_token

bearer_scheme = HTTPBearer()


async def get_current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    token = credentials.credentials
    payload = decode_access_token(token)
    if payload is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")
    user_id = payload.get("sub")
    if user_id is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")
    try:
        result = await db.execute(select(User).where(User.id == uuid.UUID(user_id)))
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    token_tenant_id = payload.get("tenant_id")
    if token_tenant_id is not None:
        if user.role != "PLATFORM_ADMIN" and str(user.tenant_id) != token_tenant_id:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token tenant mismatch")
    else:
        allow_legacy_tokens = os.environ.get("ALLOW_LEGACY_TOKENS", "false").lower() == "true"
        if not allow_legacy_tokens:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Legacy tokens not accepted")
        token_tenant_id = str(user.tenant_id)

    request.state.tenant_id = str(user.tenant_id)
    return user


def require_role(*roles: str):
    async def _check(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions")
        return current_user
    return _check
```

### backend/app/pipeline/tasks.py

547 lines — full pipeline chain implementation. Key invariants verified present:

- Pipeline order: `run_whisperx → extract_agent_identity → redact_pii → compute_talk_balance → run_groq_inference → write_scores → notify_websocket` ✓
- `extract_agent_identity` runs BEFORE `redact_pii` ✓
- `run_groq_inference` guards `pii_redacted=True` before inference ✓
- `write_scores` uses `pg_insert(...).on_conflict_do_update` scoped by `(call_id, tenant_id)` ✓
- Scoring formula: `sentiment_delta_normalized = (sentiment_delta + 1.0) / 2.0; agent_score = 0.25*politeness + 0.20*sentiment_delta_normalized + 0.20*resolution + 0.15*talk_balance + 0.20*clarity` ✓
- `display_score = round(agent_score * 10, 2)` ✓
- `talk_balance_score = round(1.0 - abs(agent_ratio - 0.5) * 2, 4)` ✓
- `SET LOCAL app.current_tenant` per transaction (never SET SESSION) ✓
- All tasks use `SET LOCAL` in `SessionLocal()` context ✓
- Model: `llama-3.3-70b-versatile` ✓
- `run_whisperx` queued to `gpu_queue` only ✓

### backend/app/routers/calls.py

477 lines — full calls router. Key invariants verified:

- Upload fires Celery chain in correct order ✓
- `minio_audio_path` used (never `audio_path`) ✓
- `pii_redacted=False` set on Call creation ✓
- `needs_agent_review=(agent_id is None)` on creation ✓
- `ALLOWED_EXTENSIONS = {".wav", ".mp3", ".m4a"}`, `MAX_FILE_SIZE = 100MB` ✓
- Duplicate upload returns existing call with HTTP 200 ✓
- Upload restricted to `TENANT_ADMIN` and `SUPERVISOR` roles ✓

---

## 5. Frontend Upload Surface

### frontend/src/pages/UploadCall.tsx (239 lines)

Full file at actual path `frontend/src/pages/UploadCall.tsx`.

Key observations:
- Frontend `MAX_FILE_SIZE = 50MB` (backend allows 100MB — intentional conservative client limit)
- Accepts `.wav`, `.mp3`, `.m4a` — matches backend `ALLOWED_EXTENSIONS`
- Sends `multipart/form-data` to `/calls/upload` via axios
- Optional `agent_id` (UUID) and `external_agent_id` (string) form fields
- No JWT in FormData — auth via `Authorization: Bearer` header injected by axios interceptor
- "Transcript" upload panel exists but marked "Coming soon" (disabled/placeholder)

```tsx
// abbreviated — key upload logic
const form = new FormData()
form.append('file', file)
if (selectedAgent) form.append('agent_id', selectedAgent)
if (externalAgentId.trim()) form.append('external_agent_id', externalAgentId.trim())
const res = await client.post<ApiResponse<UploadResponse>>('/calls/upload', form, {
  headers: { 'Content-Type': 'multipart/form-data' },
})
```

### frontend/src/store/auth.ts (33 lines)

```typescript
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'

interface User {
  id: string
  name: string
  email: string
  role: string
  tenant_name: string
  tenant_id: string
}

interface AuthState {
  token: string | null
  user: User | null
  setAuth: (token: string, user: User) => void
  clearAuth: () => void
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      token: null,
      user: null,
      setAuth: (token, user) => set({ token, user }),
      clearAuth: () => set({ token: null, user: null }),
    }),
    {
      name: 'cq-auth',
      storage: createJSONStorage(() => sessionStorage),  // sessionStorage ✓ (never localStorage)
    }
  )
)
```

### frontend/src/api/client.ts (27 lines)

```typescript
import axios from 'axios'
import { useAuthStore } from '../store/auth'

const client = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL ?? '/api',
})

client.interceptors.request.use((config) => {
  const token = useAuthStore.getState().token
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

client.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      useAuthStore.getState().clearAuth()
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

export default client
```

---

## 6. Dead Code & Debt Signals

### TODO / FIXME / XXX / HACK

```
grep -rn "TODO\|FIXME\|XXX\|HACK" backend/app/ frontend/src/
```

**Result: zero matches.** Codebase is comment-free per CLAUDE.md rule.

### Disabled / Deprecated / Unused / Old Comments

```
grep -rn -i "^\s*#.*(disabled|deprecated|unused|old)" backend/app/
```

**Result: zero matches.**

### Consecutive Commented-Out Blocks (5+ lines)

Scanned `backend/app/pipeline/tasks.py`, `backend/app/routers/calls.py`, `backend/app/database.py`.

**Result: no blocks found.**

### Noted Debt Items (structural, not comment-based)

| Location | Observation |
|----------|-------------|
| `docker-compose.hybrid.yml` | Hardcoded Windows paths (`C:\Users\adeen\...`) and plaintext credentials — dev artifact, should not reach production |
| `frontend/src/pages/UploadCall.tsx:169` | "Transcript" upload panel is permanently disabled placeholder UI — potential confusion for end users |
| `backend/Dockerfile` | `--reload` flag on prod uvicorn CMD — **development mode in the base image**; `docker-compose.prod.yml` overrides this with explicit CMD, but the image default is unsafe |
| `migrate_tokens.py` (project root) | Loose migration utility at root level, modified in working tree — not part of the main app structure |
| `celery_app.py:12-19` | Task route prefixes use `pipeline.tasks.*` but tasks are registered as `app.pipeline.tasks.*` — mismatch may cause tasks to run on default queue instead of routed queue if celery doesn't resolve the alias |

---

## 7. CI/CD Current State

### .github/workflows/ci.yml (149 lines)

```yaml
name: ci

on:
  push:
    branches: [main]    # NOTE: triggers on 'main', repo default branch is 'master'
  pull_request:

jobs:
  backend:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env: { POSTGRES_USER: callquality, POSTGRES_PASSWORD: callquality_dev, POSTGRES_DB: callquality }
        ports: ["5432:5432"]
        options: >- --health-cmd "pg_isready -U callquality -d callquality" --health-interval 10s --health-timeout 5s --health-retries 10
      redis:
        image: redis:7-alpine
        ports: ["6379:6379"]
        options: >- --health-cmd "redis-cli ping" --health-interval 10s --health-timeout 5s --health-retries 10
      minio:
        image: minio/minio
        env: { MINIO_ROOT_USER: minioadmin, MINIO_ROOT_PASSWORD: minioadmin_dev }
        ports: ["9000:9000"]
        options: >- --health-cmd "curl -f http://localhost:9000/minio/health/live" --health-interval 10s --health-timeout 5s --health-retries 10
    env:
      DATABASE_URL: postgresql://callquality:callquality_dev@localhost:5432/callquality
      REDIS_URL: redis://localhost:6379/0       # NOTE: no REDIS_PASSWORD in CI
      MINIO_ENDPOINT: localhost:9000
      GROQ_API_KEY: dummy_key
      OPENROUTER_API_KEY: dummy_key
      HF_TOKEN: dummy_token
      JWT_SECRET: ci_test_secret_32_chars_minimum_x
      WHISPER_DEVICE: cpu
      WHISPER_MODEL: base
      ALLOW_LEGACY_TOKENS: "false"
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5 (python 3.11, pip cache)
      - name: install system deps       # ffmpeg
      - name: install python deps       # requirements.txt + pytest pytest-asyncio pytest-cov ruff bandit
      - name: install playwright
      - name: create minio bucket       # via inline Python using minio SDK
      - name: alembic upgrade head
      - name: ruff lint                 # ruff check app
      - name: bandit security scan      # bandit -r app -ll
      - name: pytest                    # pytest -q --cov=app --cov-report=term-missing

  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v5 (node 20, npm cache)
      - name: install                   # npm ci
      - name: lint                      # npm run lint
      - name: build                     # npm run build (tsc + vite)
      - name: audit                     # npm audit --audit-level=high

  compose:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: validate compose config   # docker compose -f infra/docker-compose.yml config
```

**Key CI observation:** `on.push.branches: [main]` but the repo default branch is `master`. Push CI **never auto-triggers on master commits** — only PR events and pushes to `main` (which doesn't exist). This is a silent CI gap.

### Other CI configs (.gitlab-ci.yml, Jenkinsfile)

[absent]

---

## 8. Test Suite State

### Test Files Found

```
backend/tests/
├── conftest.py       [ 91 lines]
├── test_auth.py      [130 lines]
├── test_minio_event.py [104 lines]
├── test_pipeline.py  [104 lines]
└── test_scoring.py   [103 lines]
```

**Frontend test files:** [none found] — no `.test.ts`, `.test.tsx`, `.spec.ts`, or `.spec.tsx` files in `frontend/src/`.

### pytest --collect-only (run from backend/ on host)

```
ImportError while loading conftest 'backend/tests/conftest.py'.
tests/conftest.py:6: in <module>
    from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
E   ModuleNotFoundError: No module named 'sqlalchemy'
```

**Collection failed** — host Python has no dependencies installed (expected; per CLAUDE.md, pytest must run inside the `cq_api` container: `docker compose -f infra/docker-compose.app.yml exec api pytest -q`). This is not a test suite defect.

---

## 9. Git Metadata

### Current Branch

```
* master
```

### All Branches

```
* master
  remotes/origin/HEAD -> origin/master
  remotes/origin/claude/silly-neumann
  remotes/origin/copilot/audit-backend-ai-call-quality-system
  remotes/origin/copilot/audit-demo-readiness
  remotes/origin/master
  remotes/origin/phase/1.3
  remotes/origin/phase/1.4
  remotes/origin/phase/2.1
  remotes/origin/self-hosted
```

### git log --oneline -20

```
d71d676 fix(blackwell): add spaCy en_core_web_lg wheel install to Dockerfile.gpu.blackwell
5f35cbf feat(migrations): squash 8 migrations into base_schema — alembic upgrade head now works on fresh DB
fe3f4d6 chore: add MINIO_IMAGE_TAG to .env.example
95b3b5b chore: remove stale agent skills, add gitignore entry, parameterize minio tag
4b3a84a fix(L4,L5): validate coaching_summary and constrain issue_category enum
eff0683 fix(L1,L2,L3): wire jwt_expiry_seconds, email validation, boolean consistency
9aa70a5 fix(security): M4 prompt injection sanitization + duplicate call dedup
b331932 fix(H3,M1,M2,M3,M5): close five code-review findings
c5d8452 fix(H1,H2): fix presigned URL key mismatch and guard apply_async against Redis outage
3262912 chore: remove five dead code items confirmed zero callers via gitnexus
f4650d7 test: fix incorrect expected value in test_scoring and delete stale test_phase24
09f85f8 fix(pipeline): harden idempotency across write_scores, extract_agent_identity, and minio_event
2bc6e6f feat(whisper): make diarization device configurable via DIARIZE_DEVICE env-var
bcc05a6 fix: address all Codex frontend review findings
be49a07 feat: expose tenant_id in UserOut and propagate to auth store
0fde3f6 fix: address all Codex backend review findings
3ebc231 fix(critical): repair get_db_with_tenant RLS bypass and create_tenant transaction order
7732026 fix(security): OWASP audit — 5 findings fixed
a93938c chore: update GitNexus index stats and tool name references
4131b96 feat(infra): split compose architecture — B4ms app tier + NC4as_T4_v3 GPU tier
```

### git status --short (abbreviated)

```
 M CLAUDE.md
 M backend/app/models/orm.py
 M infra/docker-compose.app.yml
 M migrate_tokens.py
 M graphify-out/.graphify_root
 M graphify-out/GRAPH_REPORT.md
 M graphify-out/graph.html
 M graphify-out/graph.json
 M graphify-out/manifest.json
 D graphify-out/.graphify_analysis.json
 D graphify-out/cache/ast/*.json  [~70 deleted cache files — GitNexus re-index in progress]
```

### Repo Size

```
5.2M    .git
```

Lean — no large binaries committed to git history. (`en_core_web_lg-3.8.0-py3-none-any.whl` is in the working tree under `backend/` but that's a build artifact, not checked into history if gitignored.)

---

## Summary of Notable Findings

| # | Severity | Finding |
|---|----------|---------|
| 1 | **HIGH** | CI `on.push.branches: [main]` but repo is `master` — push CI never fires automatically on master commits |
| 2 | **MEDIUM** | `backend/Dockerfile` CMD uses `--reload` (uvicorn dev mode); prod compose overrides it, but base image is unsafe if used directly |
| 3 | **MEDIUM** | `celery_app.py` task routes use prefix `pipeline.tasks.*` while registered names are `app.pipeline.tasks.*` — verify routing works correctly in prod |
| 4 | **LOW** | `docker-compose.hybrid.yml` has hardcoded Windows paths and no REDIS_PASSWORD — dev-only, should be .gitignored or clearly labelled |
| 5 | **LOW** | No frontend tests (no `.test.tsx` / `.spec.tsx` files) |
| 6 | **INFO** | `migrate_tokens.py` is an uncommitted utility at project root — not part of the app |
| 7 | **INFO** | "Transcript upload" panel in `UploadCall.tsx` is permanently disabled placeholder |
| 8 | **INFO** | GitNexus re-index in progress (many deleted cache files in working tree) |

---

SNAPSHOT COMPLETE — 566 lines
