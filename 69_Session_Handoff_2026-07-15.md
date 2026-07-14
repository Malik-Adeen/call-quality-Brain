# Session Handoff — 2026-07-15

## COMMITTED AND PUSHED to origin/master (first time this work is in git)
- `01e8fa3` uv migration: pyproject.toml + uv.lock + 3 Dockerfiles converted to `uv sync` + ci.yml (main→master fix — CI now fires on master for the FIRST time; expect RED, 4 known test failures) + .gitignore (`.scratch-phase2/`)
- `6b471ba` tests: NullPool test engine, login 401 assertion, write_scores call sites
- `9143a8e` model: env-driven Groq model (`GROQ_INFERENCE_MODEL`, default `openai/gpt-oss-120b`), `SCORING_JSON_SCHEMA` structured output, 400/`json_validate_failed` added to fallback-advance, agent_identity.py model fix + CLAUDE.md rule updated to the MECHANISM
- `5ee0d45` docs: KNOWN_ISSUES.md (was never in git before)

## Verified this session (empirically, not assumed)
- torch in Dockerfile.gpu = 2.2.0+cu121, CUDA 12.1 — confirmed via isolated container run, NOT the full image build. uv.lock's torch is the CUDA wheel from PyPI (755MB + nvidia-*-cu12 deps), not CPU. Earlier "plain PyPI = CPU wheel" claim was WRONG, corrected.
- gpt-oss-120b live smoke call: HTTP 200 first attempt, clean JSON (no fence, no reasoning leak), all 9 fields passed InferenceResult, Groq accepted `reasoning_effort="low"` + `include_reasoning=False`, no `json_validate_failed`. ONE happy-path dummy call only — proves plumbing, NOT scoring judgment.
- Test suite: 29 passed / 4 failed / 0 errors (was 24/3/6 — the "24" was UNDER-counting; 4 tests were passing but masked as loop errors).

## Corrections to the record
- Ollama was NEVER in the pipeline (banned list). The migration was Groq llama-3.3-70b-versatile → openai/gpt-oss-120b. Code half DONE; only calibration remains.
- TWO Groq call sites exist: llm_client.py (Pydantic-validated) and agent_identity.py (raw json.loads, NO Pydantic — more fragile under a reasoning model). Both now env-driven off `GROQ_INFERENCE_MODEL` — next deprecation is a one-env-var change. agent_identity was a MISSED decommission landmine caught only by a contradiction check.
- .env is CRLF, .env.prod is LF. Both now hold the same new GROQ_API_KEY (synced this session). Normalize .env to LF someday — the stray `\r` cost a debugging detour (key read as len 57).

## 4 remaining test failures — 3 share ONE root
- HARNESS SESSION FLAW: conftest `db_session` hands ONE transaction-active async session to both the test body and the route-under-test, diverging from production (routes get fresh DI sessions; Celery workers use SYNC sessions). Symptoms:
  - `test_write_scores_idempotent` + `test_write_scores_sets_status_complete` → ValueError "Call not found" (write_scores' sync SessionLocal can't see the async fixture's uncommitted seed)
  - `test_webhook_valid_payload_creates_call_row` → InvalidRequestError "transaction already begun" (route's `async with db.begin()` on an already-in-txn session)
- 4th: `test_pii_gate_blocks_groq_when_not_redacted` — stale mock_self (bind=True self double-injection). NOT a safety failure — the guard was never reached. Fixing it moves it to the SAME ValueError. Bundle into the conftest pass.

## LOCKED next-session order
1. conftest session/transaction REDESIGN — the one deliberate reviewed-diff pass. Sync seed path (committed, visible to write_scores' sync session) + fresh-session override for route tests. Clears 3-4 reds. Do RESTED. Propose-only first, then apply.
2. Calibration — gates gpt-oss cutover before 2026-08-16. BLOCKED ON A QUESTION: do labeled ground-truth scores exist, or is this unlabeled drift comparison? Different approach each. Watch resolved / sentiment_start / sentiment_end specifically (strict mode's hardest fields).
3. Image rebuild — migration currently runs on docker cp'd code; NOT reproducible from a clean build until the GPU image is rebuilt against the new Dockerfile.
4. Batch drag-drop on deploy/fahad-demo — frontend-only, NO SSH needed (multi-file dropzone → client queue → N calls to existing /calls/upload; per-file chips; 50MB guard; GPU worker is concurrency=1 so files serialize). Scoped review, never cross-commit from master.

## BLOCKED (needs Fahad's machine — currently delayed)
- Cloudflare Tunnel (call-qa.tech, replacing Tailscale Funnel)
- Blackwell real-inference verification (whisperx@CT2 4.4.0 forced to 4.8.0, cuDNN 9 — never validated on hardware)
- Deploying master's uv work to the demo box

## STILL OPEN
- Rotate HF_TOKEN (exposed earlier) AND the old GROQ_API_KEY (printed in plaintext by tooling this session — new key already in .env/.env.prod, but revoke the old one in the Groq console).
