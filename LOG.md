---
tags: [log]
---

# LOG — Daily Session Notes

> One line per session. 30-second ritual. Saves 10 minutes next session.

---

2026-06-19 (session 2) — Final pre-Azure cleanup. Deleted batch_agent/ (replaced by MinIO webhook). Added infra/.env.example. Full graphify semantic extraction via OpenRouter DeepSeek v3: 1,061 nodes / 2,320 edges / 63 named communities. Registered openrouter-ds custom provider in ~/.graphify/providers.json. Fixed Obsidian MCP vault path in ~/.claude.json (was /obsidian-vault, now /second-brain/cqa-vault). Vault fully updated via MCP. Repo pushed — SHIP READY.\n\n2026-06-19 — Azure predeployment audit + all blockers fixed. Created Dockerfile.cpu, frontend/Dockerfile, infra/nginx.conf, infra/docker-compose.azure.yml, 20260526_platform_rls_bypass migration. Fixed SET LOCAL f-strings (set_config() bind params), notify_websocket Redis URL fallback removed. Platform_bypass migration uses remote's better pattern (modifies existing tenant_isolation policies to add OR bypass clause, not a separate policy). Resolved rebase conflicts with remote's prod Dockerfile + nginx. Pushed to GitHub master. Architecture: hybrid retired → single B4ms CPU-only self-contained. NEXT: az vm create + docker compose up. Playwright waste (M3) deferred to Phase 2.

2026-06 — Security P0 session: PyJWT migration (python-jose CVE-2024-33664 removed), Redis requirepass added, slowapi rate limiting, CORS env var, image pins, tenant-scoped DELETE in write_scores, RoleGuard on /tenants route. Platform admin: 5 pages live (overview, tenants, health, usage, call monitor) + PLATFORM_ADMIN UI via Antigravity. RLS bypass migration added (modifies tenant_isolation policies). design system changed to Waaqi GRC tokens (#00a99d primary, #0f1924 sidebar). React 18 → React 19. motion/react ^12.40.0 added.

2026-05-03 (session 2) — Architecture reviews done (DeepSeek/GLM/Kimi/Opus). Key findings: talk_balance formula wrong, pipeline not idempotent, Redis no AOF, pricing should be $15-20 not $5-10, build ROI blind-spot report before new features, South Asia = relationship sales not self-serve. Workflow formalised: Claude=auditor+prompt writer, Codex/Copilot=code generator. Research report PDF generated (Perplexity+GPT+Gemini+Manus). Tenant isolation live (Demo+Acme). Vault updated: docs 41, 42, INVARIANTS, WORKFLOW, ROADMAP. Handoff: doc 42.

2026-05-03 — Phase 7 frontend complete + E2E verified (Sarah Chen auto-assigned). Pipeline order fix (identity before PII). Login fixed (FORCE RLS + Vite proxy). Full UI polish: Login shadow card, coloured agent avatars, Sidebar accent bar, drag-drop upload, Reports WS pill, CallDetail JSON→pill. _remap_speakers bug fixed. reset_and_seed.py rewritten for multi-tenancy. .wslconfig + TDR fix for PC crashes. Gemini tasked with finding real call audio. Handoff: doc 40.

2026-05-02 — Phase 7 backend complete. Migration 006 applied locally (agent_id nullable, needs_agent_review, agent_name_extracted, external_agent_id). extract_agent_identity task live. 5 bugs caught in review pre-run. C drive 0GB incident — hibernation disabled, caches cleared, full reboot required. Notion supervisor dashboard created. Frontend remaining: Needs Review badge, manual assign, upload form.

2026-04-29 — Sea-level dashboard live. UploadResponse + radar sentiment fix applied. GPT audit cross-verified. WhisperX debug system designed (doc 28).

2026-04-19 — UI audit complete. Sea-level dashboard live (6 panels). Agents page hardened. CallList/CallDetailPanel polished. PASS verdict. 2 major issues (non-blocking): Evaluated-at label, minCalls=5 filter.

2026-04-18 — Final session on Pro account. Built custom knowledge graph builder (scripts/build_graph.py). Outputs GRAPH_REPORT.md. Added STARTUP_HYBRID.md + STARTUP_LOCAL.md. PROMPTING_GUIDE.md + INVARIANTS.md for multi-LLM workflow.
