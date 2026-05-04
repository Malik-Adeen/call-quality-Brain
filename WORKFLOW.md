---
tags: [workflow, process, invariants]
date: 2026-05-03
status: active
---

# WORKFLOW — Development Process

> This file defines how development is done on this project.
> Every LLM session must read this before writing or suggesting any code.

---

## Core Rule: Claude Audits, Codex/Copilot Generates

**Claude's role:**
- Read existing code and architecture
- Identify bugs, anti-patterns, security issues
- Write **Codex/Copilot prompts** for code generation
- Audit generated code for correctness against INVARIANTS.md
- Update vault documentation

**Claude does NOT:**
- Write or generate production code files
- This conserves tokens and keeps Claude focused on high-level reasoning

**Codex/Copilot's role:**
- Generate complete code files from Claude's prompts
- Implement features specified in prompts

---

## Session Workflow

```
1. Claude reads: GRAPH_REPORT.md (or INVARIANTS.md) + latest session handoff
2. Claude reads relevant source files to understand current state
3. Claude identifies what needs to change and why
4. Claude writes Codex prompts (numbered, specific, complete)
5. You run Codex/Copilot with the prompt
6. You paste the generated code back to Claude
7. Claude audits against INVARIANTS.md — flags any violations
8. You apply the code
9. Claude updates vault docs and writes next handoff
```

---

## Codex Prompt Format

Every Codex prompt from Claude will follow this structure:

```
CONTEXT:
[what file, what module, what it currently does]

TASK:
[exactly what to change, numbered steps]

INVARIANTS TO PRESERVE:
[specific rules from INVARIANTS.md that apply]

CONSTRAINTS:
- Zero code comments
- Complete file only, no partial snippets
- [any other constraints]

EXPECTED OUTPUT:
[what the file should look like after]
```

---

## Audit Checklist (Claude runs on every generated file)

- [ ] Zero comments in code
- [ ] `minio_audio_path` column name (never `audio_path`)
- [ ] `cq-minio:9000` hostname (hyphens, not underscores)
- [ ] `pii_redacted=TRUE` set before `run_groq_inference`
- [ ] `run_whisperx` → `gpu_queue` only
- [ ] JWT in Zustand sessionStorage (never localStorage)
- [ ] Groq model: `llama-3.3-70b-versatile` (never 3.1)
- [ ] Score stored 0–10, displayed ×10 as % in UI
- [ ] `extract_agent_identity` runs BEFORE `redact_pii` in chain
- [ ] Talk balance formula: `1 - 2 * abs(agent_ratio - 0.5)`
- [ ] Upsert guards in write_scores (no duplicate rows on retry)
- [ ] tenant_id in all queries and task args

---

## File Change Protocol

1. Claude reads the file first
2. Claude writes the Codex prompt
3. Codex generates the complete file
4. Claude audits it
5. You write it to disk
6. Claude updates session handoff
