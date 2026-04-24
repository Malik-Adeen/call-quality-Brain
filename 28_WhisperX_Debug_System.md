---
tags: [architecture, debug-system, agent-workflow]
date: 2026-04-24
status: active
---

# WhisperX Self-Improving Debug System — Architecture Spec

> Machine-readable design document. Written for LLM evaluation.

---

## 1. Project Summary

**What it is:** A terminal-based, self-improving debugging loop for a local WhisperX GPU inference pipeline. Uses a structured 6-stage agent workflow with an Obsidian vault as persistent, queryable memory.

**Problem it solves:** GPU ML pipelines (WhisperX + Pyannote + Celery) produce opaque runtime failures — CUDA OOM, ctranslate2 kernel asserts, diarization edge cases, Celery chain breaks — that require context across multiple debugging sessions to resolve. A stateless debugger rediscovers the same root causes repeatedly. This system accumulates verified fixes and anti-patterns across runs.

---

## 2. Core Architecture

```
docker logs (trimmed, 50 lines max)
        ↓
load_active_memory()
  ├── INVARIANTS.md         (hard rules, always injected)
  ├── CONTEXT.md            (project architecture, truncated to 1200 chars)
  ├── last 3 debug logs     (most recent sessions, 600 chars each)
  └── keyword match log     (error signature → related past fix, 1 match)
        ↓
AUDIT → DEBUG → PATCH → TEST → EVAL → LEARN
        ↓
write_session_summary()     (structured schema, verified outcome)
        ↓
vault updated → next session starts with this as prior context
```

**Components:**
- **Orchestrator:** Aider (terminal, git-aware, direct file patching)
- **Inference:** Groq free tier primary (llama-3.3-70b-versatile), Ollama qwen2.5-coder:7b offline fallback
- **Memory:** Obsidian vault at `N:\projects\docs\debug-logs\`
- **Log trimmer:** `trim_log.py` — extracts 50-line window around first traceback
- **Test executor:** subprocess call → `docker restart cq_worker_gpu` → capture 30-line tail
- **Escalation router:** keyword trigger list → swaps inference endpoint mid-session

---

## 3. Workflow Loop

| Stage | Action |
|---|---|
| **AUDIT** | Classify error type (CUDA/Celery/Python/network) and identify affected pipeline stage |
| **DEBUG** | Identify root cause from trimmed log + memory context; propose minimal fix |
| **PATCH** | Aider applies fix to target file; git auto-commit with stage label |
| **TEST** | `docker restart cq_worker_gpu`; capture 30-line log tail after 15s wait |
| **EVAL** | Compare error signature before vs after: PASS / FAIL / PARTIAL |
| **LEARN** | Write structured summary to vault with verified outcome + "Do Not Repeat" field |

Loop re-enters at DEBUG if EVAL returns FAIL, with test result injected into prompt.
Loop exits on PASS or after 3 failed iterations (escalates to human).

---

## 4. Model Strategy

| Tier | Model | When Used |
|---|---|---|
| Primary | Groq free — `llama-3.3-70b-versatile` | All sessions with internet access |
| Fallback | Ollama `qwen2.5-coder:7b` on CPU | Offline / Groq rate-limited |
| Never | Any GPU-loaded local model | GPU occupied by WhisperX at all times |

**Escalation triggers (auto, keyword-based):**
```python
ESCALATE_KEYWORDS = ["ctranslate2", "CUDA assert", "pyannote", "RTTM",
                     "botocore", "diarization", "MissingGreenlet", "asyncpg"]
```
If any keyword matches the current error log, inference routes to Groq regardless of tier.

**VRAM rule:** Ollama never runs while `cq_worker_gpu` container is active. Mutually exclusive by design.

---

## 5. Obsidian Vault Usage

**Location:** `N:\projects\docs\debug-logs\`

**What is stored (per session, structured schema):**
```markdown
## Error Fingerprint
[exact error class + file + line number]

## Hypothesis Tried
[model's stated root cause]

## Fix Applied
[exact code diff or description]

## Test Result
[PASS / FAIL / PARTIAL + evidence line from log]

## Do Not Repeat
[what was tried and confirmed not to work]
```

**When it is read:**
- At session start: always (INVARIANTS + CONTEXT + last 3 logs)
- Mid-session: on keyword match during AUDIT stage

**How it is queried:**
- Recency: `sorted(glob("*.md"), key=mtime, reverse=True)[:3]`
- Keyword: regex match of error class names, file paths, library names against all log bodies

**How it improves future runs:**
- "Do Not Repeat" field prevents fix rediscovery loops
- Related past fix injection surfaces working solutions from prior sessions
- Verified outcomes (not assumed) prevent vault self-poisoning

---

## 6. Current Constraints

| Constraint | Detail |
|---|---|
| GPU | RTX 3060 Ti 8GB VRAM — fully occupied by WhisperX during inference |
| CPU inference | 4–6 tokens/sec on 7B model — loop latency 8–15 min offline |
| Cost | $0 target — Groq free tier (rate-limited), Ollama as offline fallback |
| Tool choice | Aider: terminal-native, no server, direct git-aware file patching |
| Context window | Capped at 4K tokens per prompt — log trimmer enforces this |
| Connectivity | SSH tunnel to Azure — debug system runs locally, pipeline on hybrid topology |

---

## 7. Known Limitations

| Limitation | Impact | Accepted? |
|---|---|---|
| Groq rate limits | Session may stall waiting for quota reset | Yes — offline fallback covers it |
| Keyword match ≠ semantic match | Wrong past fix injected for superficially similar errors | Partially — mitigated by "Do Not Repeat" field |
| TEST stage has 15s fixed wait | Fast-failing containers may be misclassified as PASS | Accepted for demo scope |
| No automated rollback | Bad patch may break downstream imports before TEST catches it | Mitigated by Aider git commits — manual `git revert` required |
| CPU fallback is slow | 3-stage loop = 8–15 min offline — user abandons manually | Accepted — Groq is primary |
| Vault write quality | Free-form summaries degrade recall — structured schema enforced | Enforced in `write_session_summary()` |
| Single model reasoning | No cross-validation of diagnosis — one model's hypothesis drives PATCH | Accepted — adding agents doesn't fix this, better model does |
