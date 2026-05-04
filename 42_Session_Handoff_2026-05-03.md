---
tags: [handoff, session-starter, llm-agnostic]
date: 2026-05-03
status: active
---

# 42 — Session Handoff 2026-05-03

> Paste INVARIANTS.md + this file at the start of any working session.
> For Codex/Copilot sessions: paste INVARIANTS.md only + the specific task prompt.

---

## ⚡ Development Workflow (read this first)

**Claude = auditor + prompt writer. Codex/Copilot = code generator.**

- Claude reads code, identifies issues, writes Codex prompts
- Codex/Copilot generates complete files from those prompts
- Claude audits generated code against INVARIANTS.md
- Claude does NOT write production code — conserves tokens

See `WORKFLOW.md` for full process.

---

## Current State — v1.7 (as of 2026-05-03)

**System:** All local Docker. Azure VM deleted.
**Alembic head:** `20260701_agent_identity`
**Pipeline chain:** run_whisperx → extract_agent_identity → redact_pii → compute_talk_balance → run_groq_inference → write_scores → notify_websocket
**Multi-tenancy:** Triple-layer RLS verified. Two tenants (Demo + Acme Corp) live.
**Architecture reviews:** Done — DeepSeek/GLM/Kimi/Opus. See `41_Architecture_Review_Synthesis`.

---

## Critical Bugs Found in Architecture Review (fix before coding new features)

### Fix 1 — Talk Balance Formula (10 min, correctness bug)
**File:** `backend/app/pipeline/tasks.py` → `compute_talk_balance` function

Current (wrong):
```python
talk_balance_score = round(1.0 - abs(agent_ratio - 0.5) * 2, 4)
# wait — actually check what's in the file, may already have old ratio logic
```

Correct formula:
```python
agent_ratio = agent_words / total_words if total_words > 0 else 0.5
talk_balance_score = round(1.0 - abs(agent_ratio - 0.5) * 2, 4)
```
Agent talking 100% → score 0.0. Perfect 50/50 → score 1.0.

### Fix 2 — Redis AOF Persistence (2 lines, prevents task loss on restart)
**File:** `infra/docker-compose.yml` → `cq_redis` service

Add to redis command:
```yaml
command: redis-server --appendonly yes --appendfsync everysec
```

### Fix 3 — write_scores upsert guard (prevents duplicate rows on GPU crash/retry)
**File:** `backend/app/pipeline/tasks.py` → `write_scores` function

Before inserting CallMetrics and SentimentTimeline, delete existing rows for this call_id:
```python
db.execute(delete(CallMetrics).where(CallMetrics.call_id == call_id))
db.execute(delete(SentimentTimeline).where(SentimentTimeline.call_id == call_id))
# then insert fresh — already done actually, verify this is in place
```

---

## MVP Phase Order (confirmed post architecture review)

```
Phase A — 3 Quick Fixes (above, ~1 session)
Phase B — UI Redesign (Notion/Intercom, dark/light mode, indigo #6366F1)
Phase C — Register page + POST /auth/register
Phase D — Agent Management GUI (CRUD)
Phase E — User Management GUI (invite supervisors/viewers)
Phase F — Batch Upload Agent (Docker watchdog)
Phase G — ROI Blind Spot Report (get first customer)
```

**Note from Opus/Kimi reviews:** Phase G (go talk to customers with 50 real calls) should happen in parallel with Phase B-F, not after. Don't build features nobody asked for.

---

## How to Start Any Session

```powershell
# Bring containers up
cd N:\projects\call-quality-analytics\infra
docker compose up -d

# Start frontend
cd N:\projects\call-quality-analytics\frontend && npm run dev

# Verify
Invoke-RestMethod -Uri "http://localhost:8000/health"
```

Login: `admin@callquality.demo / admin1234`
Second tenant: `admin@acme.demo / acme1234`

---

## Files Changed This Session (2026-05-03)

```
backend/app/pipeline/tasks.py          — pipeline order fix, _remap_speakers bug fix
backend/app/routers/calls.py           — PATCH /assign-agent, tenant scoping, nullable agent
backend/app/routers/agents.py          — tenant scoping on all queries (Codex fix)
backend/app/routers/reports.py         — tenant scoping on PDF export (Codex fix)
backend/app/schemas/api.py             — tenant_name in UserOut, AssignAgentRequest
backend/app/routers/auth.py            — tenant_name in login response
backend/app/services/whisper_service.py — CUDA cleanup + _remap_speakers bug fix
frontend/src/App.tsx                   — sidebar margin 176px, header simplified
frontend/src/components/Sidebar.tsx    — tenant name pill, coloured avatar, accent bar
frontend/src/components/CallDetailPanel.tsx — agent_name_extracted pill, assign control
frontend/src/pages/Login.tsx           — shadow card, show/hide password, focus rings
frontend/src/pages/Agents.tsx          — coloured avatars, shadow cards, strengths panel
frontend/src/pages/CallList.tsx        — Needs Review badge, null agent, onCallUpdated
frontend/src/pages/Reports.tsx         — offset shadow, WS pill, null agent, spinner
frontend/src/pages/UploadCall.tsx      — drag-drop zone, file size, shadow card
frontend/src/store/auth.ts             — tenant_name added to User interface
frontend/src/types/api.ts              — CallSummary nullable, tenant_name in LoginResponse
frontend/vite.config.ts                — proxy fixed to localhost:8000
scripts/reset_and_seed.py              — tenant_id throughout, upsert users, idempotent
scripts/generate_test_audio.py         — no-pydub version (Python 3.14 compatible)
infra/.wslconfig                       — memory=10GB cap (prevents PC crashes)
docs/INVARIANTS.md                     — talk balance formula corrected, workflow section added
docs/WORKFLOW.md                       — NEW: Claude=auditor, Codex=generator process
docs/ROADMAP.md                        — updated with arch review findings
docs/00_Master_Dashboard.md            — v1.7 complete
docs/41_Architecture_Review_Synthesis_2026-05-03.md — NEW: all 4 reviews synthesised
docs/42_Session_Handoff_2026-05-03.md  — this file
docs/LOG.md                            — session entry added
```

---

## Key Decisions Made This Session

| Decision | Rationale |
|---|---|
| Claude audits, Codex generates | Token efficiency, quality separation |
| Price at $15–20/agent (not $5–10) | Opus + Kimi: low price = "student project" in B2B |
| South Asia first, relationship sales (not self-serve) | BPO purchasing is relationship-driven |
| Urdu ASR: defer, use SeamlessM4T+LID router instead of QLoRA | GLM + Opus: get customers first |
| Batch agent: bulk upload page first, Docker agent later | Opus: wrong architecture for most BPOs |
| `extract_agent_identity` stays before `redact_pii` | Correct — names would be <PERSON> after redaction |
| Architecture review postmortem in doc 41 | Reference for all future sessions |

---

## For Next Session

1. Run the 3 quick fixes (talk balance, Redis AOF, write_scores guard)
2. Verify fixes with `python scripts/reset_and_seed.py` + upload test audio
3. Begin Phase B (UI redesign) — load ckmui-styling and ui-ux-pro-max skills first
4. When Gemini returns real audio URLs → paste and download for diarization testing
5. Run `python scripts/build_graph.py` to regenerate GRAPH_REPORT.md
6. Git commit everything

---

## Docs to Load for Specific Work

| Task | Load These |
|---|---|
| Any session start | `INVARIANTS.md` + this file |
| Pipeline changes | + `41_Architecture_Review_Synthesis_2026-05-03.md` |
| Frontend work | + `21_UI_Redesign_Postmortem.md` + ckmui-styling skill |
| Auth/tenant work | + `35_Session_Handoff_2026-05-01.md` |
| Audio/pipeline debugging | + `26_Audio_Testing_Postmortem.md` |
| FYP report writing | + `CONTEXT.md` + `03_API_Contract.md` |
