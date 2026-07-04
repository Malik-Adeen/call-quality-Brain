# Session Handoff — 2026-07-04

Branch `chore/cleanup-2026-06` merged/pushed to `master` at `c952b11`. `origin/master` confirmed at `c952b11`; sync your local `master` (currently behind by 1).

## What Changed

**This session (c952b11) — router/service split, pipeline stages split, frontend decomposition:**
- `backend/app/routers/agents.py` 499→127 lines — logic extracted to `services/agents_service.py`
- `backend/app/routers/calls.py` 477→155 lines — logic extracted to `services/calls_service.py`
- `backend/app/routers/platform.py` 539→122 lines — logic extracted to `services/platform_service.py`
- `backend/app/pipeline/tasks.py` 547→17 lines — 7 stages split into `pipeline/stages/*.py`, `tasks.py` is now a thin re-export shim
- `frontend/src/pages/Overview.tsx` 632→148 lines — extracted to `components/overview/*` + `utils/overviewCalculations.ts`
- `frontend/src/components/CallDetailPanel.tsx` 446→193 lines — extracted to `components/call-detail/*` + `utils/callDetailTransforms.ts`
- `frontend/src/App.css` deleted (superseded by Tailwind design tokens)
- `backend/tests/conftest.py`: `TEST_DATABASE_URL` host `localhost`→`cq_postgres` (in-container test connectivity)
- Router→service split verified fully wired (not orphaned scaffolding) via GitNexus impact/context checks + grep cross-referencing
- Celery task gate check passed: all 7 stage tasks have explicit `name=` kwargs, all match `task_routes` keys exactly
- Dead code scan (GitNexus, index refreshed to 1,570 symbols / 2,503 edges / 62 flows): 0 confirmed dead code. All "zero-caller" candidates were false positives from FastAPI route handlers, Celery task registration, React JSX component usage, and Zustand hook access — none of which register as `CALLS` edges in GitNexus's graph for this codebase

**Earlier commits on master (already merged before this session, included for handoff completeness):**
- `graphify-out/` untracked (removed from git, added to `.gitignore`)
- `ctranslate2` pinned to `4.8.0` for Blackwell GPU compatibility
- Postgres port fixed to `5433`
- `write_scores` invariant doc fix, `orm.py`/`migrate_tokens.py` formatting

## Infrastructure Decision: Cloudflare Tunnel

`call-qa.tech` (Cloudflare Tunnel) will replace Tailscale Funnel as the canonical public URL. Setup pending on Fahad's machine — not yet done.

## Next Up (in order)

1. **uv migration** — move Python dependency management to `uv`, split into three dependency groups
2. **CI fix** — (see known issue below: `ci.yml` triggers on `main`, repo is `master`, so push CI currently never fires)
3. **CI/CD security decision** — pending

## Known State

- `deploy/fahad-demo` (remote tip `96e5705`) forked from master at `d71d676` and has **not** received any cleanup-branch changes since (`176c950`, `eaaba15`, `c952b11` all absent). This is intentional — it's a separate demo environment on Fahad's Blackwell machine, not meant to track cleanup work. Its one commit since divergence (`96e5705`) is Blackwell-specific (CT2 4.8.0, torch.load monkeypatch, dedup constraint drop, auth RLS bypass, Groq key fix).
- Backend pytest baseline: **24 passed / 3 failed / 6 errored — pre-existing, not a regression.** Failures: `test_login_wrong_password`, `test_webhook_valid_payload_creates_call_row`, `test_write_scores_idempotent` (arg-count). Errors: 6 async-loop fixture-scoping issues. Documented since 2026-06-23 (LOG.md), unchanged through this cleanup.
- Frontend build: clean, no TS/build errors.
