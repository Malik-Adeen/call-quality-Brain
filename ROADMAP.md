---
tags: [planning, roadmap]
date: 2026-05-03
status: active
---

# ROADMAP — AI Call Quality & Agent Performance Analytics

> Updated post architecture review (DeepSeek/GLM/Kimi/Opus — May 2026).
> See doc 41 for full review synthesis.
> Development workflow: Claude audits + writes prompts. Codex/Copilot generates code.

---

## Completed Phases

### Phase 1 — Foundation
7-service Docker stack. JWT auth. MinIO upload. Celery queue isolation. [[07_Phase1_Postmortem]]

### Phase 2 — AI Pipeline
WhisperX + Pyannote. Presidio PII gate. Groq inference. Atomic scoring. WebSocket. [[13_Phase2_E2E_Postmortem]]

### Phase 3 — React Dashboard
6 pages. Recharts. Slide-in panels. PDF export. [[21_UI_Redesign_Postmortem]]

### Phase 4 — Production Hardening
Playwright PDF. Azure B2s (now deleted). SSH tunnel. Extended Presidio PII. [[23_Phase4_Postmortem]]

### Phase 5 — Multi-Tenancy
Migrations 001–004: tenants, tenant_id, RLS, FORCE RLS. JWT tenant_id claim. Celery explicit tenant_id. [[35_Session_Handoff_2026-05-01]]

### Phase 6 — Agent Integration
Migration 005. POST /agents/sync. GET /agents. AgentListItem schema. [[36_Session_Handoff_2026-05-02]]

### Phase 7 — Agent Identity Extraction
Migration 006. extract_agent_identity task. PATCH /assign-agent. Needs Review badge. Pipeline order fix (identity before redaction). [[37_Phase7_Postmortem]]

### UI Polish Pass (May 2026)
Login shadow card. Sidebar tenant pill + coloured avatar. Agents coloured cards. Reports WS pill. Upload drag-drop. CallDetail assign control. Tenant isolation verified (Demo + Acme Corp). [[40_Session_Handoff_2026-05-03]]

---

## Active — Phase 8: MVP Hardening

### Phase 8A — Architecture Review Fixes (1 session)
**Source:** Doc 41 — Architecture Review Synthesis

- [ ] Fix `compute_talk_balance` → `1 - 2 * abs(agent_ratio - 0.5)`
- [ ] Add Redis AOF persistence (`--appendonly yes --appendfsync everysec`)
- [ ] Add upsert guards in `write_scores` (delete then insert, idempotent on retry)
- [ ] Verify `write_scores` delete-before-insert already in place
- [ ] LLM score variance test (run same call 20x, measure spread)

### Phase 8B — UI Redesign (2–3 sessions)
Notion/Intercom aesthetic. Dark/light mode. Indigo #6366F1 accent. Dark sidebar always.
Inter font only (drop Playfair, JetBrains Mono from UI chrome).
Dark/light toggle in top-right header.

**Load before starting:** ckmui-styling skill + ui-ux-pro-max skill

Pages to redesign: Login, Sidebar, App layout, Overview, CallList, CallDetail, Agents, Reports, UploadCall

### Phase 8C — Register Page + POST /auth/register (1 session)
Self-serve company signup → creates tenant + admin user in one transaction.

Backend: `POST /auth/register` → INSERT tenants → INSERT users (TENANT_ADMIN role)
Frontend: `Register.tsx` with company name, email, password

### Phase 8D — Agent Management GUI (1 session)
Full CRUD for agents via dashboard. Currently agents only via sync API.

Backend: `POST /agents` (create), `PATCH /agents/:id` (edit), `DELETE /agents/:id` (deactivate)
Frontend: `AgentManagement.tsx` — table with add/edit/deactivate

### Phase 8E — User Management GUI (1 session)
TENANT_ADMIN invites supervisors and viewers.

Backend: `GET /users`, `POST /users/invite`, `DELETE /users/:id`
Frontend: `UserManagement.tsx` — list users, invite form, deactivate

### Phase 8F — Batch Upload Agent (1–2 sessions)
Sandboxed Docker watchdog container. Read-only volume mount.

Architecture (post-Kimi review):
- SHA-256 checksum sent with upload (API = source of truth, not SQLite)
- asyncio semaphore for 3–5 concurrent uploads
- Adaptive backoff on 429/503
- inotify/watchdog for filesystem events
- Health endpoint on :8080

Frontend: `BatchAgent.tsx` — configure path, set agent, start/stop, live feed

---

## Phase 9 — First Customer (parallel with 8B–8F)

**The ROI Blind Spot Report** (Opus + Kimi: build this before any new features)

1. Get 50 real call recordings from a local BPO (NDA, free)
2. Process overnight via pipeline
3. Build one-page report: "Your QA process caught X of these 5 worst calls. Here's what happened on the other Y."
4. Present in person. Ask for 30-day paid pilot at $15–20/agent/month.

This is not a feature — it's a sales motion. Assign a timebox to it.

---

## Phase 10 — Urdu/English ASR (post-revenue)

**Approach revised post architecture review (GLM recommendation):**

Instead of QLoRA fine-tuning WhisperX:
1. **Language Identification (LID) router** at segment level (fastText)
2. Pure English segments → standard WhisperX large-v2
3. Pure Urdu segments → dedicated Urdu ASR model
4. Code-switched segments → Meta SeamlessM4T

QLoRA fine-tuning deferred until:
- 50+ hours of transcribed code-switched BPO audio available
- At least one paying South Asian BPO customer

---

## Phase 11 — Real-Time Streaming Transcription

WebSocket audio chunk receiver. WhisperX streaming. Live transcript word-by-word.
**Requires:** Stable customer base first. Not for MVP.

---

## Deferred / Cancelled

| Item | Status | Reason |
|---|---|---|
| Azure B2s deployment | Cancelled | Credits exhausted. All-local Docker. |
| QLoRA Whisper fine-tuning (near-term) | Deferred | No training data, no customers. Use SeamlessM4T instead. |
| CRM integration | Deferred | Post-first-customer |
| Priority customer scoring | Deferred | Post-first-customer |
| Mobile supervisor app | Deferred | Post-revenue |

---

## Architecture Review Findings — Impact on Roadmap

From doc 41 (May 2026 review):

| Finding | Impact |
|---|---|
| Talk balance formula wrong | Fixed in Phase 8A |
| Pipeline not idempotent | Fixed in Phase 8A |
| Redis no persistence | Fixed in Phase 8A |
| Scoring weights hardcoded | Backlog — post first customer |
| LLM variance untested | Run test in Phase 8A |
| Presidio misses South Asian PII | Backlog — before EU expansion |
| No human-in-the-loop | Backlog — Phase 9+ |
| Celery chain brittle | Accepted for now — major rework post-revenue |
| Price too low ($5–10) | Operational decision — price at $15–20 |
