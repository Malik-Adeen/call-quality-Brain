# 03 — API & WebSocket Contract
> **LLM Anchor Document.** Paste this alongside `01_Master_Architecture.md` when building
> any FastAPI route or any React component that calls the API.
> Every field name, type, and envelope shape defined here is final.

---

## Global Response Envelope

Every endpoint — success or error — uses this exact wrapper. No bare JSON responses.

**Success**
```json
{
  "success": true,
  "data": {},
  "error": null,
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error**
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "MACHINE_READABLE_CODE",
    "message": "Human readable description.",
    "field": "agent_id"
  },
  "request_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

---

## POST /auth/login

**Request** — `application/json`
```json
{
  "email": "admin@callquality.demo",
  "password": "plaintext_password"
}
```

**Response 200** — `data` payload
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 28800,
  "user": {
    "id": "uuid",
    "name": "Demo Admin",
    "email": "admin@callquality.demo",
    "role": "ADMIN"
  }
}
```

**Error codes**
| HTTP | code | Condition |
|---|---|---|
| 401 | `INVALID_CREDENTIALS` | Email or password incorrect |
| 422 | `VALIDATION_ERROR` | Malformed request body |

---

## POST /calls/upload

**Request** — `multipart/form-data`

| Field | Type | Constraint |
|---|---|---|
| `file` | `File` | `.wav` `.mp3` `.m4a` — max 100 MB |
| `agent_id` | `string` (UUID) | Must exist in `agents` table |

**Response 202** — `data` payload
```json
{
  "call_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "pending",
  "minio_audio_path": "audio-uploads/agent-uuid/2025/03/08/4f3a1b2c9e7d.wav",
  "message": "Audio queued for processing."
}
```

**Error codes**
| HTTP | code | Condition |
|---|---|---|
| 400 | `INVALID_FILE_TYPE` | Extension not in allowed list |
| 400 | `FILE_TOO_LARGE` | Exceeds 100 MB |
| 400 | `AGENT_NOT_FOUND` | `agent_id` UUID not in `agents` table |
| 403 | `FORBIDDEN` | `VIEWER` role cannot upload |

---

## GET /calls

**Query parameters** — all optional

| Param | Type | Default | Notes |
|---|---|---|---|
| `agent_id` | UUID | — | Filter to one agent |
| `status` | string | — | `pending` `processing` `complete` `failed` |
| `resolved` | boolean | — | `true` or `false` |
| `score_min` | float | — | Inclusive lower bound |
| `score_max` | float | — | Inclusive upper bound |
| `date_from` | ISO 8601 | — | `2025-01-01` |
| `date_to` | ISO 8601 | — | `2025-12-31` |
| `issue_category` | string | — | e.g. `billing_dispute` |
| `page` | int | `1` | |
| `page_size` | int | `20` | Max 100 |
| `sort_by` | string | `created_at` | `created_at` `score` `duration` |
| `sort_dir` | string | `desc` | `asc` `desc` |

**Response 200** — `data` payload
```json
{
  "calls": [
    {
      "id": "uuid",
      "agent_id": "uuid",
      "agent_name": "Sarah Chen",
      "agent_team": "Support",
      "duration": 342,
      "score": 7.85,
      "resolved": true,
      "status": "complete",
      "issue_category": "billing_dispute",
      "sentiment_start": -0.42,
      "sentiment_end": 0.65,
      "created_at": "2025-03-01T14:22:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total_count": 200,
    "total_pages": 10
  }
}
```

---

## GET /calls/{id}

**Response 200** — `data` payload
```json
{
  "id": "uuid",
  "agent_id": "uuid",
  "agent_name": "Sarah Chen",
  "agent_team": "Support",
  "minio_audio_path": "audio-uploads/agent-uuid/2025/03/08/4f3a1b2c9e7d.wav",
  "transcript_redacted": "AGENT: Hello, how can I help you today?\nCUSTOMER: Hi, I have a question about my <CREDIT_CARD> charge.",
  "duration": 342,
  "score": 7.85,
  "resolved": true,
  "status": "complete",
  "issue_category": "billing_dispute",
  "coaching_summary": "Agent demonstrated strong active listening. Sentiment improved from -0.42 to +0.65 across the call duration. One area for improvement: the hold notification at 2:30 could have been issued 20 seconds earlier.",
  "pii_redacted": true,
  "sentiment_start": -0.42,
  "sentiment_end": 0.65,
  "created_at": "2025-03-01T14:22:00Z",
  "metrics": {
    "politeness_score": 0.82,
    "sentiment_delta": 0.34,
    "resolution_score": 0.91,
    "talk_balance_score": 0.48,
    "clarity_score": 0.79
  },
  "diarized_segments": [
    {
      "speaker": "AGENT",
      "start": 0.0,
      "end": 4.82,
      "text": "Hello, how can I help you today?",
      "words": [
        {"word": "Hello", "start": 0.0, "end": 0.44},
        {"word": "how", "start": 0.52, "end": 0.68}
      ]
    },
    {
      "speaker": "CUSTOMER",
      "start": 5.1,
      "end": 10.34,
      "text": "Hi, I have a question about my <CREDIT_CARD> charge.",
      "words": [
        {"word": "Hi", "start": 5.1, "end": 5.32}
      ]
    }
  ],
  "sentiment_timeline": [
    {"timestamp_seconds": 0, "sentiment_value": -0.42},
    {"timestamp_seconds": 60, "sentiment_value": -0.18},
    {"timestamp_seconds": 120, "sentiment_value": 0.21},
    {"timestamp_seconds": 180, "sentiment_value": 0.48},
    {"timestamp_seconds": 240, "sentiment_value": 0.65}
  ]
}
```

**Error codes**
| HTTP | code | Condition |
|---|---|---|
| 404 | `CALL_NOT_FOUND` | UUID does not exist |
| 403 | `FORBIDDEN` | `SUPERVISOR` requesting another team's call |

---

## GET /agents/{id}/scores

**Query parameters**

| Param | Type | Default |
|---|---|---|
| `days` | int | `30` |

**Response 200** — `data` payload
```json
{
  "agent": {
    "id": "uuid",
    "name": "Sarah Chen",
    "team": "Support"
  },
  "summary": {
    "avg_score": 7.82,
    "total_calls": 42,
    "resolved_count": 31,
    "resolution_pct": 73.8,
    "avg_politeness": 0.84,
    "avg_clarity": 0.79,
    "avg_talk_balance": 0.475
  },
  "score_history": [
    {"date": "2025-02-01", "score": 7.4, "call_count": 3},
    {"date": "2025-02-02", "score": 8.1, "call_count": 4}
  ],
  "team_avg_score": 6.95
}
```

---

## POST /reports/export

**Request** — `application/json`
```json
{
  "call_id": "uuid"
}
```

**Response 200**
```
Content-Type: application/pdf
Content-Disposition: attachment; filename="call_report_<call_id>.pdf"
<binary PDF bytes>
```

**Error codes**
| HTTP | code | Condition |
|---|---|---|
| 503 | `PDF_SERVICE_UNAVAILABLE` | Playwright container not reachable |
| 404 | `CALL_NOT_FOUND` | call_id does not exist |

---

## WebSocket — ws://api:8000/ws/{user_id}

**Connection:** authenticate via JWT query param — `?token=<access_token>`
Authentication happens at connection time. No auth message required after connect.

---

### Event: `call_complete`

Emitted by `notify_websocket` task immediately after `write_scores` commits.

```json
{
  "type": "call_complete",
  "call_id": "uuid",
  "agent_id": "uuid",
  "agent_name": "Sarah Chen",
  "score": 7.85,
  "resolved": true,
  "timestamp": "2025-03-01T14:22:45Z"
}
```

---

### Event: `pipeline_error`

Emitted if any pipeline stage raises an unhandled exception.

```json
{
  "type": "pipeline_error",
  "call_id": "uuid",
  "stage": "redact_pii",
  "message": "Presidio analyzer timeout after 30s"
}
```

---

### Event: `processing_update`

Optional progress heartbeat emitted at the start of each stage.

```json
{
  "type": "processing_update",
  "call_id": "uuid",
  "stage": "run_whisperx",
  "status": "running"
}
```

---

## TypeScript Interfaces

Paste the following directly into `/frontend/src/types/api.ts`.

```typescript
export interface ApiResponse<T> {
  success: boolean
  data: T | null
  error: ApiError | null
  request_id: string
}

export interface ApiError {
  code: string
  message: string
  field?: string
}

export interface CallSummary {
  id: string
  agent_id: string
  agent_name: string
  agent_team: string
  duration: number
  score: number
  resolved: boolean
  status: "pending" | "processing" | "complete" | "failed"
  issue_category: string
  sentiment_start: number
  sentiment_end: number
  created_at: string
}

export interface CallDetail extends CallSummary {
  minio_audio_path: string
  transcript_redacted: string
  coaching_summary: string
  pii_redacted: boolean
  metrics: CallMetrics
  diarized_segments: DiarizedSegment[]
  sentiment_timeline: SentimentPoint[]
}

export interface CallMetrics {
  politeness_score: number
  sentiment_delta: number
  resolution_score: number
  talk_balance_score: number
  clarity_score: number
}

export interface DiarizedSegment {
  speaker: "AGENT" | "CUSTOMER"
  start: number
  end: number
  text: string
  words: WordTimestamp[]
}

export interface WordTimestamp {
  word: string
  start: number
  end: number
}

export interface SentimentPoint {
  timestamp_seconds: number
  sentiment_value: number
}

export interface WsCallComplete {
  type: "call_complete"
  call_id: string
  agent_id: string
  agent_name: string
  score: number
  resolved: boolean
  timestamp: string
}

export interface WsPipelineError {
  type: "pipeline_error"
  call_id: string
  stage: string
  message: string
}

export interface WsProcessingUpdate {
  type: "processing_update"
  call_id: string
  stage: string
  status: "running"
}

export type WsEvent = WsCallComplete | WsPipelineError | WsProcessingUpdate
```

### Exemption Note
The GET /health endpoint is exempt from the standard ApiResponse envelope. It returns a bare JSON object (e.g., {"status": "ok"}) to maintain compatibility with standard infrastructure health probes.