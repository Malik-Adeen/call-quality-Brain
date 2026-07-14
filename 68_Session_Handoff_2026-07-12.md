# 68 — Session Handoff — 2026-07-12

## uv migration — Phase 3 lock COMPLETE (uncommitted)

- `uv.lock` generated successfully. Gate PASSED: pyannote.core 5.0.0, pyannote.metrics 3.2.1, numpy 1.26.4, torch 2.2.0 (CUDA-12.1, no cu13), av 11.0.0 (sdist), whisperx 3.2.0, faster-whisper 1.0.0, ctranslate2 4.4.0.
- `pyproject.toml` final `[tool.uv]`: `override-dependencies = [numpy==1.26.4, pyannote.core==5.0.0, pyannote.metrics==3.2.1, torch==2.2.0]` + `[[tool.uv.dependency-metadata]]` `av` 11.0.0 `requires-dist=[]` (av is sdist-only, forced by faster-whisper; metadata declared so uv skips the host build — av still compiles inside GPU images on FFmpeg 4.4).
- **ROOT-CAUSE CORRECTION** for the multi-session numpy/pyannote saga: it was a phantom for the uv target. Override pinned numpy alone; pyannote.core floated to 6.0.1 (numpy>=2) and torch to 2.13.0 (CUDA-13). Extending overrides to the versions the phase2 image already runs fixed it. The Phase 2 AMI-diarization correctness gate was ABANDONED (tested the wrong hypothesis — core 5.0.0 declares numpy>=1.10.4, no ceiling, so no unsupported combo to certify). faster-whisper-large-v2 cache grind was unnecessary (diarization uses pyannote models, not the transcription model); scratch cache `~/.cache/huggingface-phase2test` deleted.
- ALL UNCOMMITTED. Next uv step (NOT started): Dockerfile uv-sync conversion, 4 files, diff-reviewed — carries the per-image torch decision (master 2.2.0 from lock vs Blackwell 2.7 installed separately: `uv sync --no-install-package torch` + per-Dockerfile torch). Blackwell real-inference verification still deferred (needs GB hardware).

## Test suite — baseline was mislabeled

- Started 24p/3f/6e → now 29p/4f/0e. NullPool on `_test_engine` (conftest) cleared all 6 "attached to a different loop" errors (module-scope async engine sharing an asyncpg pool across function-scoped loops) AND revealed 4 tests that were passing-but-masked — real baseline was 28 passing, not 24. The recorded "24/3/6 known baseline" was under-counting real coverage and hiding a stale test as an accepted constant.
- Fixes applied this session (ALL UNCOMMITTED, in test files + conftest, docker cp'd into cq_api which has no bind mount): NullPool (conftest.py); MINIO_WEBHOOK_SECRET env set in conftest; login test 401 (route was correct — returns 401 enveloped; test wrongly asserted 200); two stale-mock_self removals in test_pipeline (test_write_scores_idempotent, test_write_scores_sets_status_complete).
- TEST BUG CLASS found: redundant `mock_self` passed as a 5th arg to bind=True Celery tasks (self is auto-injected). 3 instances — 2 fixed (write_scores), 1 unfixed (test_pii_gate_blocks_groq_when_not_redacted, on run_groq_inference). NOTE: the PII gate is NOT a safety failure — the guard was never reached, only the arg count broke. Recommend a grep sweep for any other direct bind=True task calls in tests/.

## 4 remaining failures — 3 share ONE root

- HARNESS SESSION FLAW (root of 3): conftest db_session hands ONE transaction-active async session to both the test body and the route-under-test via dependency_overrides — diverging from production (routes get a fresh DI session; Celery workers use SYNC sessions). Symptoms:
  - `test_write_scores_idempotent` + `test_write_scores_sets_status_complete` → ValueError "Call not found" (write_scores opens app SYNC SessionLocal, can't see the async fixture's uncommitted seed).
  - `test_webhook_valid_payload_creates_call_row` → InvalidRequestError "transaction already begun" (route's `async with db.begin()` on a session the test already has in a txn).
- 4th: test_pii_gate mock_self (trivial). Removing it will move it to the SAME "Call not found" ValueError as the write_scores pair.

## LOCKED next-session order

1. conftest session/transaction REDESIGN — the one deliberate reviewed-diff pass. Fixes 3+ reds at once: sync seed path (committed, visible to write_scores' sync session) for worker tests; fresh-session override for route tests so `db.begin()` owns its own txn. Do rested.
2. Finish mock_self sweep (pii_gate + grep tests/ for other bind=True direct calls).
3. uv Dockerfile uv-sync conversion (4 files; per-image torch; Blackwell deferred).
4. Commit uv work and test work as SEPARATE logical commits after diff review (master only).

## Tomorrow — separate track (Fahad SSH lands)

- Frontend batch drag-drop on deploy/fahad-demo (frontend-only: multi-file dropzone → client queue → N calls to existing /calls/upload; per-file chips; existing 50MB guard; GPU worker is concurrency=1 so files serialize).
- Groq model migration: llama-3.3-70b-versatile DEPRECATED, decommission 2026-08-16. Move to openai/gpt-oss-120b via STRUCTURED-OUTPUT mode (gpt-oss is a reasoning model — the current "respond ONLY with JSON" prompt will break; use JSON-schema, not prompt-only). Both branches (config lives on master AND deploy/fahad-demo). Re-validate all 5 score components. Do it as its own validated pass, ideally AFTER the demo if demo < Aug 16.

## STILL OPEN

- HF_TOKEN rotation — exposed in plaintext earlier this session, unrelated to any thread.
