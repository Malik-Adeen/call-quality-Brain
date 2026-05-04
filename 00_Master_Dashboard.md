---
tags: [moc, dashboard]
status: active
created: 2026-04-11
updated: 2026-05-03 (session 5)
---

# 00 — Master Dashboard

> Single entry point for the entire knowledge vault.
> Read this first at the start of any working session.
> For LLM sessions: Claude reads [[GRAPH_REPORT]] via filesystem (fastest) or paste [[INVARIANTS]] (500 tokens).

---

## Project Identity

| Property | Value |
|---|---|
| System | AI Call Quality & Agent Performance Analytics System |
| Type | B2B SaaS product (pivoted from FYP — April 30, 2026) |
| Builder | Malik Adeen — BSCS, Bahria University Islamabad |
| Repo | https://github.com/Malik-Adeen/call-quality-analytics |
| Local path | N:\projects\call-quality-analytics |
| Vault | N:\projects\docs |
| Cloud | None — Azure resources deleted (credits exhausted). Building cloud-agnostic locally. |
| FYP demo | Completed — week of April 21, 2026 |
| Instructor confirmed | Phase 5 → 6 → 7. CRM + Priority deferred. (2026-04-30) |

---

## Build State — v1.7 (Phase 7 Complete, UI Polish Pass Done)

| Phase | Description | Status | Notes |
|---|---|---|---|
| 1 | Foundation — Auth, Upload, Docker, Celery | ✅ | [[07_Phase1_Postmortem]] |
| 2.1 | WhisperX GPU + Pyannote diarization | ✅ | [[08_Phase2.1_Postmortem]] |
| 2.2 | Presidio PII redaction gate | ✅ | [[09_Phase2.2_Postmortem]] |
| 2.3 | Groq LLM inference | ✅ | [[11_Phase2.3_Postmortem]] |
| 2.4 | Scoring + chain + WebSocket | ✅ | [[12_Phase2.4_Postmortem]] |
| 2 E2E | Full pipeline end-to-end verified | ✅ | [[13_Phase2_E2E_Postmortem]] |
| Audit | Security fixes | ✅ | [[14_Audit_Fixes]] |
| 3A | Backend read endpoints | ✅ | [[16_Phase3A_Read_Endpoints]] |
| 3 | React dashboard — 6 pages | ✅ | [[17_Phase3_Frontend]] |
| UI | Light parchment redesign | ✅ | [[21_UI_Redesign_Postmortem]] |
| 4 | PDF + Azure B2s + Hybrid SSH tunnel | ✅ (Azure deleted) | [[23_Phase4_Postmortem]] |
| Hybrid | SSH tunnel + WAN Celery tuning | ✅ (Azure deleted) | [[24_Hybrid_Architecture_Postmortem]] |
| Audio | 5 real call recordings verified | ✅ | [[26_Audio_Testing_Postmortem]] |
| PII+ | Extended Presidio recognizers | ✅ | [[27_Presidio_Extension_Postmortem]] |
| Phase 5 — DB | Migrations 001–004: tenants, tenant_id, RLS, FORCE RLS | ✅ | [[35_Session_Handoff_2026-05-01]] |
| Phase 5 — Auth | JWT tenant_id claim + ContextVar middleware | ✅ | [[35_Session_Handoff_2026-05-01]] |
| Phase 5 — Workers | Celery explicit tenant_id arg — all 6 tasks | ✅ | [[36_Session_Handoff_2026-05-02]] |
| Phase 6 | Agent Integration — Migration 005, POST /agents/sync, GET /agents | ✅ | [[36_Session_Handoff_2026-05-02]] |
| **Phase 7** | **Agent Identity Extraction from Audio** | ✅ | [[37_Phase7_Postmortem]] |
| **UI Polish** | **Login, Sidebar, Agents, Reports, Upload, CallDetail, CallList** | ✅ | [[40_Session_Handoff_2026-05-03]] |
| Phase 8 | CRM Integration — DEFERRED | ⏸ | [[30_SaaS_Pivot_Plan]] |
| Phase 9 | High / Low Priority Customers — DEFERRED | ⏸ | [[30_SaaS_Pivot_Plan]] |

---

## Phase 7 Checklist (complete)

```
[x] Migration 006 — agent_id nullable, needs_agent_review, agent_name_extracted, external_agent_id on calls
[x] orm.py — Call model updated with 4 new columns
[x] tasks.py — extract_agent_identity task live in pipeline chain
[x] Pipeline order fix — extract_agent_identity runs BEFORE redact_pii (raw text)
[x] _remap_speakers bug fixed — else "CUSTOMER" → else "AGENT"
[x] PATCH /calls/{id}/assign-agent endpoint
[x] Upload form — agent optional, external_agent_id field
[x] CallList — Needs Review badge, null agent handling
[x] CallDetailPanel — manual assign control, agent_name_extracted parsed (no raw JSON)
[x] Vite proxy fixed — localhost:8000 (was pointing at deleted Azure VM)
[x] FORCE RLS removed from users table (login fix)
[x] reset_and_seed.py — tenant_id throughout, upsert users, idempotent
[x] E2E verified — Sarah Chen auto-identified and assigned from audio
```

## UI Polish Checklist (complete)

```
[x] Login — shadow card, show/hide password, focus rings, error box styling
[x] Sidebar — narrowed to 176px, coloured initials avatar, green active accent bar, LogOut icon
[x] Agents — deterministic coloured avatars, box-shadow card lift, trend arrows, coloured strengths panel
[x] Overview — no changes (charts preserved exactly)
[x] CallList — Needs Review badge, Unassigned italic, null-safe filter, onCallUpdated prop
[x] CallDetailPanel — agent_name_extracted pill (name + confidence colour), amber assign control
[x] Reports — offset shadow card, WS status pill, null agent handling, export spinner
[x] UploadCall — drag-and-drop zone, file size display, shadow card, focus rings
[x] App.tsx — sidebar margin corrected (176px), header simplified
```

---

## Alembic State

| Migration | Revision ID | Status |
|---|---|---|
| 001 Create tenants | `20260501_create_tenants` | ✅ Applied |
| 002 Add tenant_id | `20260501_add_tenant_id` | ✅ Applied |
| 003 RLS + roles | `20260501_enable_rls` | ✅ Applied |
| 004 FORCE RLS | `20260501_force_rls` | ✅ Applied |
| 005 Agent sync columns | `20260601_add_agent_sync_columns` | ✅ Applied |
| 006 Agent identity extraction | `20260701_agent_identity` | ✅ Applied |

Current head: `20260701_agent_identity`

> ⚠️ Revision IDs must be ≤32 characters — alembic_version.version_num is VARCHAR(32)

---

## Known Issues / Workarounds

| Issue | Workaround | Fix |
|---|---|---|
| gTTS test audio — all speakers labelled AGENT | Use real phone recordings | Pyannote can't separate synthetic TTS voices |
| Talk Balance 0% on gTTS audio | Same — real audio needed | gTTS is mono, one speaker detected |
| users table FORCE RLS blocks login | `ALTER TABLE users NO FORCE ROW LEVEL SECURITY` — applied | Auth router bypasses RLS as table owner |
| PC crashes after 2-3 uploads | .wslconfig memory cap + TDR registry fix | WSL2 memory unbounded; NVIDIA TDR timeout |
| Call List no auto-refresh after processing | Navigate away and back | WebSocket update only on Reports page |

---

## Startup Runbook

All services run locally. Hybrid/Azure runbooks are historical — Azure VM deleted.

```powershell
cd N:\projects\call-quality-analytics\infra
docker compose up -d
cd N:\projects\call-quality-analytics\frontend && npm run dev
```

Login: admin@callquality.demo / admin1234

---

## LLM Context Loading (fastest to slowest)

| Method | Tokens | How |
|---|---|---|
| `GRAPH_REPORT.md` via filesystem | ~1,100 | Claude reads directly — no paste needed |
| `INVARIANTS.md` paste | ~500 | For Qwen/Gemini sessions |
| `CONTEXT.md` paste | ~2,500 | Full architecture for complex decisions |

Update graph after code changes: `python scripts/build_graph.py`

---

## Vault Index

| File | Purpose |
|---|---|
| [[GRAPH_REPORT]] | Auto-generated knowledge graph |
| [[CONTEXT]] | Universal LLM context |
| [[INVARIANTS]] | 500-token rules block |
| [[ROADMAP]] | B2B SaaS phase planning |
| [[40_Session_Handoff_2026-05-03]] | Last session handoff — start here |
| [[38_Session_Handoff_2026-05-02]] | Previous session (Phase 7 backend) |
| [[34_Final_Implementation_Plan]] | Research-complete implementation plan |
| [[01_Master_Architecture]] | Stack manifest, pipeline, scoring formula |
| [[03_API_Contract]] | All endpoint shapes + TypeScript interfaces |
| [[20_New_Design_System]] | Light parchment design tokens |
