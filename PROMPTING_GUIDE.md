# PROMPTING_GUIDE — AI Call Quality Analytics System

> Project-specific prompt templates and token efficiency rules.
> Source: synthesized from Claude Sonnet (project context) + Claude Opus (strategic advice).
> Last updated: 2026-04-17

---

## 1. Model Routing Matrix

Default to Qwen local. Escalate only when needed. Most tasks never pass Qwen.

| Task | Model | Why |
|---|---|---|
| Architecture decisions, phase planning | Claude (web) | Reasoning depth, vault context via project files |
| Multi-file refactors (chain reshape, schema rippling to ORM+Pydantic+TS) | Claude web | Needs consistency across 3+ files — weaker models drift |
| Async / Celery / concurrency debugging | Claude | Qwen produces plausible-wrong code here |
| Docker + compose + networking failures | Claude | Multi-layer failures need full system reasoning |
| Groq prompt engineering for scoring | Claude | Shapes downstream DB values — quality matters |
| Obsidian postmortems | Claude | Synthesis quality shows in future context |
| React WebSocket hooks, audio sync, reconnection logic | Claude | Stateful + timing-sensitive |
| Single-file Pydantic schemas matching a spec | Qwen2.5-Coder 7B local | Deterministic pattern work, offline, free |
| CRUD route scaffolding (existing route as template) | Qwen local | Copy-a-pattern is its sweet spot |
| pytest for pure functions (scoring formula, talk_balance) | Qwen local | Formulaic |
| Recharts KPICard, basic Tailwind layouts | Qwen local | Boilerplate |
| TypeScript interface from JSON example | Qwen local | Mechanical |
| Reading 10+ vault files to answer one question | Gemini 2.5 Pro (AI Studio) | 2M context, free, no token anxiety |
| Research (Presidio coverage, pyannote quirks, CUDA images) | Gemini or Claude w/ search | Gemini is free |
| Reading long error traces + full log files + Dockerfile | Gemini | Free, handles giant blobs |
| Overflow when Claude credits run out mid-phase | OpenRouter → claude-sonnet-4.6 or DeepSeek V3 | Pay-per-token |
| Strategic FYP decisions (once a month) | Claude Opus | Architecture, multi-LLM workflow, viva prep |

**Harsh rule:** Never use Claude for a task Qwen can do. Scaffolding a Pydantic model
you already have an example of is Qwen work.

---

## 2. The Rules Block (paste before every session, every LLM)

Keep this under 300 tokens. Put invariants as bullets — not prose.
Smaller models follow bullet rules more reliably than paragraphs.

```
Project: call-quality-analytics (FastAPI + Celery + Redis + MinIO + PostgreSQL + React)
Repo: github.com/Malik-Adeen/call-quality-analytics

RULES — no exceptions:
- Zero comments in generated code. None.
- minio_audio_path (never audio_path)
- MinIO host: cq-minio (hyphens — underscores break botocore)
- Network: cq_network
- API uses AsyncSessionLocal; Celery workers use SessionLocal (psycopg2 sync)
- DATABASE_URL: postgresql+asyncpg:// for API, postgresql:// for workers
- run_whisperx → gpu_queue (concurrency=1, prefetch=1); everything else → io_queue
- Speaker labels: "AGENT" or "CUSTOMER" — never SPEAKER_00/SPEAKER_01
- JWT in Zustand sessionStorage — never localStorage
- Audio binary never in database
- pii_redacted=True set before any downstream stage
- numpy<2 is the LAST pip install in Dockerfile.gpu
- Package is nvidia-ml-py — never pynvml
- Groq model: llama-3.3-70b-versatile (never 3.1 — deprecated)
- Banned: Ollama in pipeline, VADER, WeasyPrint, Node.js backend

SCORING FORMULA (invariant — never modify weights):
agent_score = 0.25*politeness + 0.20*((sentiment_delta+1)/2) + 0.20*resolution + 0.15*talk_balance + 0.20*clarity
display_score = round(agent_score * 10, 2)  # stored 0-10, shown as % in UI
```

---

## 3. Claude Template (Architecture / Complex Debug)

```
[RULES BLOCK]

Phase [N], Step [M]: [task description]

RELEVANT CONTEXT:
[paste ONLY the section of CONTEXT.md that applies — not the whole file]

ERROR (if applicable):
[exact error + stack trace]

FILE (if applicable):
[only the relevant file — not all files]
```

---

## 4. Qwen2.5-Coder Local Template (Boilerplate / Code Generation)

```powershell
# Start Qwen
ollama run qwen2.5-coder:7b
```

Paste before every Qwen request:
```
[RULES BLOCK]

You are generating code for this project. Follow rules exactly.
No comments. Complete files only — no partial snippets.

EXISTING PATTERN TO FOLLOW:
[paste one example of similar existing code]

TASK: [exactly what to generate]

OUTPUT: Complete file, ready to save as [filename]
```

---

## 5. Gemini Template (Research / Long Context / Vault Queries)

```
[RULES BLOCK]

Treat attached vault files as ground truth.
If something is not in spec, say "not in spec" — do not guess.
Zero comments in any code you produce.

TASK: [Research / Vault Query / Code Review]
[For vault queries: paste entire N:\projects\docs contents]
[For research: domain, constraints, application]
```

---

## 6. OpenRouter Fallback Template

Same as Claude template. Add at top:
```
Model: [claude-sonnet-4.6 / deepseek-chat / qwen-2.5-coder-32b-instruct]
[RULES BLOCK]
```

Best OpenRouter models for this project:
- `anthropic/claude-sonnet-4.6` — identical to Claude web, pay-per-token
- `google/gemini-2.0-flash` — very cheap (~$0.10/M), good for code
- `qwen/qwen2.5-coder-32b-instruct` — best free coding model

---

## 7. Opus Template (Strategic Decisions Only)

Reserve for decisions that affect months of work: multi-LLM workflow,
Phase 5 Urdu ASR approach, FYP report structure, viva prep.

```
I am a final year CS student. [RULES BLOCK]

Attached: CONTEXT.md (full project architecture)

Strategic question: [one focused, precise question]
```

---

## 8. Context Size Reference

| What you paste | Approx tokens |
|---|---|
| Rules block only | ~250 |
| Rules + one postmortem | ~600 |
| Rules + CONTEXT.md §3–5 | ~900 |
| Full CONTEXT.md | ~2,500 |
| Full CONTEXT.md + API contract | ~4,000 |
| Full vault (all files) | ~30,000 |

**Claude Basic target:** Keep sessions under 4,000 input tokens.
For anything needing more → Gemini 1.5/2.5 Pro (free, 1–2M context).

---

## 9. Context Compression Techniques (from Opus)

**Invariants distillation.** Maintain INVARIANTS.md (under 500 tokens) with only
non-negotiable rules. Paste this into Qwen/Gemini — not the full vault.

**Phase context packs.** One file per phase: PHASE_5_CONTEXT.md. Only what's needed
for that phase. When working on Urdu ASR you don't need MinIO cache-volume gotchas.

**Postmortem folding.** After a phase is 2+ weeks old, distill the "Bugs & Resolutions"
table into a 5-bullet "Lessons" list inside INVARIANTS.md. The raw postmortem stays in
vault for audit; the distilled version is what LLMs see.

**Reference by filename.** Instead of pasting 02_Database_Schema.sql, say:
"Columns per 02_Database_Schema.sql — assume spec is correct." Only paste when needed.

**Conversation restart hygiene.** After ~30 turns, start fresh. Carry forward only:
current phase/step + relevant file excerpts + last successful state.

---

## 10. FYP-Length Workflow Patterns (from Opus)

**Escalation ladder — default Qwen, escalate only when it fails:**
Qwen local → Gemini free → Claude Basic → OpenRouter → Opus (strategic only)

**Daily state snapshot ritual.** End of every session, append one line to LOG.md:
`2026-04-17 — Phase 4 done. tech_support.mp3 → 88.2%. Presidio extended.`
30 seconds. Saves 10 minutes next session.

**Vault is primary memory, conversation is ephemeral.** Extract every useful
decision into the vault before closing. If it's only in chat history, it doesn't exist.

**Weekly invariants audit.** Reread INVARIANTS.md weekly. If an invariant is violated
in code and nobody noticed, it's dead — reinstate in code or remove from doc.
Dead invariants corrupt future sessions.

**Defense prep sessions (final 2 weeks).** Not code. Architecture Q&A rehearsal.
Use Claude/Opus for mock viva questions:
- "Why Celery over FastAPI BackgroundTasks?"
- "Why Presidio over spaCy NER?"
- "Why SSH tunnel over Tailscale for the GPU connection?"
- "Why PostgreSQL + MinIO instead of a document store?"
This is high-value Claude usage — don't skimp here.

**Watch for vault bloat.** If a doc isn't consulted for 3 weeks, fold it into
something else or move to `archive/`. Vault should shrink as invariants stabilize.

---

## 11. Phase 5 Urdu ASR Context Block

Add this to every ML-related prompt when Phase 5 starts:

```
PHASE 5 CONTEXT:
- Target: Urdu/English code-switched telephonic ASR
- Hardware: RTX 3060 Ti 8GB VRAM
- Approach: QLoRA fine-tuning of WhisperX base model (4-bit quantization)
- Constraint: Must fit in 8GB VRAM with LoRA rank 16
- Reference: CHiPSAL workshop findings (06_Urdu_ASR_Research.md)
- Target WER: <10% on held-out Urdu-English test set
- Data need: 15-20 hours labeled Urdu/English telephonic audio
```

---

## 12. Ollama Setup (Qwen2.5-Coder Local)

```powershell
winget install Ollama.Ollama
ollama pull qwen2.5-coder:7b    # ~4GB VRAM — use when WhisperX is NOT loaded
ollama pull qwen2.5-coder:14b   # ~8GB VRAM — use when Docker is idle
ollama run qwen2.5-coder:7b
```

**Critical:** Never run Qwen + WhisperX simultaneously. Both fight for VRAM.
Qwen for coding sessions. WhisperX for inference sessions. Never both.
