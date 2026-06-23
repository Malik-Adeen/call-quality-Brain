---
tags: [handoff, session-starter]
date: 2026-05-03
status: active — paste this + INVARIANTS.md at next session start
---

# 43 — Session Handoff (Next Chat)

> Workflow: Claude = auditor + Codex prompt writer. Codex/Copilot = code generator.
> Claude does NOT write production code. Conserves tokens, maintains quality.
> See WORKFLOW.md for full process.

---

## Current State — v1.7

- All local Docker. Azure VM deleted.
- Alembic head: `20260701_agent_identity`
- Pipeline: run_whisperx → extract_agent_identity → redact_pii → compute_talk_balance → run_groq_inference → write_scores → notify_websocket
- Multi-tenancy: triple-layer RLS. Demo Tenant + Acme Corp verified isolated.
- Architecture reviews done (DeepSeek/GLM/Kimi/Opus) — findings in doc 41.
- Design system confirmed: Notion official tokens from DESIGN.md (doc 20).

---

## TASK 1 — 3 P0 Bug Fixes (do first, ~30 min total)

### Fix A — Talk Balance Formula (tasks.py)
Current code is WRONG — agent talking 100% scores 1.0 (inflated).

**Codex prompt to write:**
```
Read backend/app/pipeline/tasks.py. Find compute_talk_balance.
Replace the talk_balance_score calculation with:
  agent_ratio = agent_words / total_words if total_words > 0 else 0.5
  talk_balance_score = round(1.0 - abs(agent_ratio - 0.5) * 2, 4)
This maps: 50/50 = 1.0, 100/0 = 0.0, 70/30 = 0.6.
Zero comments. Return complete file only.
```

### Fix B — Redis AOF Persistence (docker-compose.yml)
Task queue is lost if Redis container restarts.

**Codex prompt to write:**
```
Read infra/docker-compose.yml. Find the cq_redis service.
Add this line under the service:
  command: redis-server --appendonly yes --appendfsync everysec
Zero comments. Return complete file only.
```

### Fix C — write_scores idempotency (tasks.py)
Verify delete-before-insert exists for CallMetrics and SentimentTimeline.
If missing: add `db.execute(delete(CallMetrics).where(CallMetrics.call_id == call_id))` 
and same for SentimentTimeline BEFORE the inserts.

---

## TASK 2 — Full UI Redesign

### Design System: Notion Official (doc 20_New_Design_System.md)

**Key tokens to know:**

```
Canvas:     #ffffff
Surface:    #f6f5f4   (sidebar bg, secondary surface)
Surface-soft: #fafaf9 (hover states)
Hairline:   #e5e3df   (default borders)
Hairline-strong: #c8c4be (input borders)

Text primary:   #1a1a1a (ink)
Text secondary: #37352f (charcoal)
Text muted:     #787671 (steel)
Text disabled:  #bbb8b1

Primary CTA:    #5645d4  (Notion purple — only CTA colour)
Primary hover:  #4534b3

Success: #1aae39   Warning: #dd5b00   Error: #e03131

Pastel cards:
  mint:     #d9f3e1   lavender: #e6e0f5   sky:    #dcecfa
  peach:    #ffe8d4   yellow:   #fef7d6   cream:  #f8f5e8
```

**Typography:** Inter only. 400/500/600 weights. 14px body-sm, 16px body-md, 11px micro-uppercase for labels.

**Shape rules:**
- Buttons: `rounded-lg` (8px) — RECTANGLES not pills
- Cards: `rounded-xl` (12px)
- Badges: `rounded-full` (9999px) — pills ONLY for badges
- Inputs: 44px height, 8px radius, purple focus border `#5645d4`

**Dark mode:** Defer. Light mode first. Add toggle after.

### Files to redesign (in this order):

**Step 1 — index.css**
Replace all CSS variables with Notion tokens. Keep font imports.
Drop: Playfair Display, JetBrains Mono from body (keep mono ONLY for score values/timestamps).
Add Inter 400/500/600.

**Step 2 — App.tsx**
- Sidebar: 240px fixed, bg `#f6f5f4`, right border `#e5e3df`
- Header: 56px, bg `#ffffff`, bottom border `#e5e3df`, sticky
- Main content: bg `#ffffff`, left margin 240px
- Header right: dark mode toggle icon (placeholder for now)

**Step 3 — Sidebar.tsx**
- bg `#f6f5f4`, width 240px
- Brand: 56px area, logo in 28px black box, "QA.SYSTEM" 14px/600
- Tenant pill: bg `#ede9e4`, 11px/600 uppercase, 6px radius
- Nav links: 6px radius, active: bg `#ede9e4` + left `2px solid #5645d4`
- User avatar: 28px, initials, deterministic colour from name hash
- NEW ANALYSIS button: bg `#000` text `#fff` 14px/500 8px radius

**Step 4 — Login.tsx**
- Centered card on `#f6f5f4` background
- Card: bg `#fff`, border `#e5e3df`, 12px radius, padding 40px, max-w 400px
- Purple "Sign in" button full-width
- Input: 44px height, purple focus ring

**Step 5 — Overview.tsx**
- Stat cards: pastel tint backgrounds (mint for resolved, sky for scores, peach for at-risk)
- All charts: Recharts config from doc 20 (purple `#5645d4` primary line)
- Section headers: 14px/600 uppercase `#787671` — NEVER remove or reorder charts

**Step 6 — CallList.tsx**
- Table: Notion table tokens (header bg `#f6f5f4`, rows hover `#fafaf9`)
- Score badges: mint/yellow/red pastel (not solid colours)
- "Needs Review" badge: peach bg `#ffe8d4` text `#dd5b00`
- Filter buttons: outlined secondary style

**Step 7 — CallDetailPanel.tsx**
- Slide panel: bg `#ffffff`, left border `#e5e3df`
- Assignment section: peach tint `#ffe8d4`, left border `#dd5b00` 3px
- Radar chart: purple `#5645d4` stroke
- All metric pills: pastel tints matching semantic meaning

**Step 8 — Agents.tsx**
- Cards: white bg, `#e5e3df` border, 12px radius
- Active card: `2px solid #5645d4` border
- Score progress bar: purple `#5645d4` fill
- Trend chips: mint/yellow/red pastel
- Score chart: purple line

**Step 9 — Reports.tsx**
- Table: Notion table tokens
- WS status: pastel badge (mint when live, gray when offline)
- Export button: ghost style with download icon

**Step 10 — UploadCall.tsx**
- Drop zone: dashed `#c8c4be` border, hover dashed `#5645d4`
- File selected: solid `#5645d4` border, mint bg hint
- Submit: full-width purple button
- Card: white bg, `#e5e3df` border, 12px radius

---

## TASK 3 — New Pages (after redesign)

### Register.tsx + POST /auth/register
Single transaction: INSERT tenants → INSERT users (TENANT_ADMIN).
Page: company name, email, password, confirm. Links back to login.

### AgentManagement.tsx
Table + inline add/edit modal. Soft deactivate (is_active=false).
Backend: POST, PATCH, DELETE /agents.

### UserManagement.tsx
List users within tenant. Invite form (email + role). Deactivate button.
Backend: GET /users, POST /users/invite, DELETE /users/:id.

### BatchAgent (Phase 8F — last)
Docker watchdog. SHA-256 checksum dedup. asyncio semaphore 3-5 uploads.
inotify/watchdog events. Health :8080. Config: watch_path, api_url, api_token.

---

## Startup

```powershell
cd N:\projects\call-quality-analytics\infra && docker compose up -d
cd N:\projects\call-quality-analytics\frontend && npm run dev
```

Login 1: `admin@callquality.demo / admin1234`  (Demo Tenant — 200 calls)
Login 2: `admin@acme.demo / acme1234`           (Acme Corp — 0 calls)

---

## Audit Checklist (run on every Codex-generated file)

- [ ] Zero code comments
- [ ] `minio_audio_path` never `audio_path`
- [ ] `cq-minio:9000` hyphens
- [ ] `extract_agent_identity` BEFORE `redact_pii`
- [ ] Talk balance: `1 - 2 * abs(agent_ratio - 0.5)`
- [ ] Score: stored 0–10, displayed ×10 as %
- [ ] JWT in sessionStorage never localStorage
- [ ] Groq: `llama-3.3-70b-versatile`
- [ ] Notion design: `#5645d4` purple, 8px buttons, 12px cards, Inter only

---

## Pending Items

- GPT architecture review (no credits — paste when available, Claude will internalise)
- Real call audio from Gemini (paste URLs when returned)
- LLM score variance test (20-run same call, measure spread)
- Git commit: `git add -A && git commit -m "Arch reviews, vault updated, workflow formalised"`
