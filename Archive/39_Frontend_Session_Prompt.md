---
tags: [session-prompt, phase7, frontend, skills]
date: 2026-05-02
status: ready
---

# 39 — Phase 7 Frontend Session Prompt

> Paste this entire file at the start of the next Claude chat session.
> Works best in Claude Desktop with skills installed.

---

## Skills to Activate (type `/` in Claude Desktop)

1. **redesign-skill** — fitting new components into an existing system, not greenfield
2. **UI/UX Pro Max** — component-level UX rules, touch targets, accessibility, interaction states
3. **Playwright MCP** — screenshot existing components before editing, verify output visually after

---

## Context Block (paste this)

```
You are a Senior Frontend Engineer helping build Phase 7 of an AI Call Quality Analytics System.

SKILLS: Use redesign-skill + UI/UX Pro Max for all component work.
Use Playwright MCP to screenshot each component BEFORE editing so you can see the current state,
and screenshot AFTER to verify the output matches the existing design system.

EXISTING DESIGN SYSTEM (non-negotiable — match exactly):
- bg: #E4E3E0 warm parchment
- score_high: #10b981 (>80%)
- score_mid: #141414 (60-80%)
- score_low: #ef4444 (<60%)
- needs_review: #f59e0b (yellow-amber — new for Phase 7)
- Fonts: Inter body, JetBrains Mono data, Playfair Display italic headers
- Stack: React 18 + TypeScript + TailwindCSS v4 + Recharts
- Zero code comments. Complete files only. No partial snippets.

PROJECT RULES (invariants — never violate):
- Score stored 0-10 in DB, displayed ×10 as % in UI
- agent_id is now nullable — handle null gracefully in all components
- needs_agent_review: boolean — yellow badge when true
- JWT in Zustand sessionStorage — never localStorage
- API response envelope: { success, data, error, request_id }
- New endpoint available: PATCH /calls/{id}/assign-agent { agent_id: uuid }

COMPONENT FILES: I will paste each file before asking you to modify it.
Review each file against redesign-skill rules before generating output.
```

---

## Task 1 — PATCH /calls/{id}/assign-agent endpoint (backend, do first)

**Codex prompt:**
```
Add a new endpoint to backend/app/routers/calls.py:

PATCH /calls/{call_id}/assign-agent

Request body: { "agent_id": "uuid" }
Auth guard: SUPERVISOR or TENANT_ADMIN only

Logic:
1. Load call by call_id with SET LOCAL app.current_tenant (RLS)
2. Validate agent_id exists and belongs to same tenant and is_active=True
3. Set call.agent_id = agent_uuid
4. Set call.needs_agent_review = False
5. Return ApiResponse with updated call summary

Return: ApiResponse[CallSummary]
Error codes: CALL_NOT_FOUND, AGENT_NOT_FOUND, FORBIDDEN

Zero comments. Complete file only.
```

Paste output here for review before running.

---

## Task 2 — Upload form (UploadCall.tsx)

**Playwright MCP first:**
```
Screenshot http://localhost:5173/upload so I can see the current upload form state.
```

**Then Codex prompt:**
```
Modify frontend/src/pages/UploadCall.tsx.

Changes:
1. Agent dropdown: change from required to optional
   - Add placeholder option "Agent (auto-detect from audio)"
   - Label changes to "Agent (optional — leave blank for auto-detection)"
2. Add new optional text input below agent dropdown:
   - Label: "Agent ID (telephony system)"
   - Placeholder: "e.g. EXT001"
   - Field name: external_agent_id
   - Helper text: "If provided, skips AI name detection entirely"
3. Update form submission: pass external_agent_id alongside file and agent_id

Use redesign-skill. Match existing form field styling exactly.
Zero comments. Complete file only.
```

**Playwright MCP after:**
```
Screenshot http://localhost:5173/upload to verify the new fields match the existing design.
```

---

## Task 3 — Needs Review badge (CallList.tsx)

**Playwright MCP first:**
```
Screenshot http://localhost:5173/calls so I can see the current call list row layout.
```

**Then Codex prompt:**
```
Modify frontend/src/pages/CallList.tsx.

Add a "Needs Review" badge to call rows where needs_agent_review === true.

Badge spec:
- Color: #f59e0b background, white text (amber-500 in Tailwind)
- Text: "Needs Review"
- Size: same as existing status badges in the row
- Position: inline with agent name, immediately after it
- Only shown when needs_agent_review === true AND agent_id is null

Also handle null agent_id gracefully:
- agent_name: show "Unassigned" in muted text when null
- agent_team: show "—" when null

Use redesign-skill. Match existing badge styling from score badges.
Zero comments. Complete file only.
```

**Playwright MCP after:**
```
Screenshot http://localhost:5173/calls to verify badge renders correctly.
```

---

## Task 4 — Manual assign control (CallDetailPanel.tsx)

**Playwright MCP first:**
```
Click any call row to open the detail panel, then screenshot so I can see current panel layout.
```

**Then Codex prompt:**
```
Modify frontend/src/components/CallDetailPanel.tsx.

Add manual agent assignment control, shown only when needs_agent_review === true OR agent_id is null.

Control spec:
- Section header: "Agent Assignment" with amber warning icon
- Dropdown: list of active agents fetched from GET /agents
- Button: "Assign Agent" — calls PATCH /calls/{id}/assign-agent
- On success: refresh call detail, hide the control, show brief success toast
- On error: show inline error message

Placement: below the score section, above the transcript section.

Also update the agent display at top of panel:
- When agent_id is null: show "Unassigned" with amber "Needs Review" pill
- When agent assigned: show agent name + team as normal

Use redesign-skill + UI/UX Pro Max touch target rules (min 44px height on all interactive elements).
Zero comments. Complete file only.
```

**Playwright MCP after:**
```
Screenshot the open call detail panel to verify the assignment control renders correctly.
```

---

## E2E Smoke Test (run after all 4 tasks complete)

```powershell
# 1. Upload a file with NO agent selected
# Watch worker_io logs
docker logs cq_worker_io -f

# 2. After pipeline completes, verify DB
docker exec cq_postgres psql -U callquality -d callquality -c \
  "SELECT agent_id, needs_agent_review, agent_name_extracted FROM calls ORDER BY created_at DESC LIMIT 1;"

# 3. Open call list in browser — verify Needs Review badge appears
# 4. Open call detail — verify assign control appears
# 5. Assign an agent — verify badge disappears, agent name populates
```

---

## Files to Paste for Each Task

| Task | Paste these files |
|---|---|
| Task 1 (backend) | `backend/app/routers/calls.py` |
| Task 2 (upload form) | `frontend/src/pages/UploadCall.tsx` |
| Task 3 (call list) | `frontend/src/pages/CallList.tsx`, `frontend/src/types/api.ts` |
| Task 4 (detail panel) | `frontend/src/components/CallDetailPanel.tsx`, `frontend/src/types/api.ts` |

---

## After Phase 7 Completes

1. Run E2E smoke test above
2. Update `N:\projects\docs\37_Phase7_Postmortem.md` — mark all frontend tasks done
3. Update `N:\projects\docs\00_Master_Dashboard.md` — Phase 7 → ✅
4. Add row to Notion Weekly Updates: https://www.notion.so/354506f0067381cbb715d3f5356cac20
5. Run `python scripts/build_graph.py` to regenerate GRAPH_REPORT.md
