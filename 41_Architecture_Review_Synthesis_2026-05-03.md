---
tags: [architecture, review, postmortem]
date: 2026-05-03
reviewers: DeepSeek R1, GLM 5.1, Kimi, Claude Opus 4.6
status: reference — internalised
---

# 41 — Architecture Review Synthesis (May 2026)

> Four external AI architecture reviews commissioned: DeepSeek R1, GLM 5.1, Kimi, Claude Opus 4.6.
> This document synthesises findings by confidence level and priority.
> **Do not code anything from this doc without checking ROADMAP.md for current phase.**

---

## Consensus Findings (3–4 reviewers agreed = highest confidence)

### P0 — Fix Before Any Customer Data

| # | Finding | Reviewers | Fix Required |
|---|---------|-----------|--------------|
| 1 | **Talk balance formula mathematically wrong** | DeepSeek, GLM, Kimi | Use `1 - 2*abs(agent_ratio - 0.5)` not raw ratio. Agent talking 100% currently scores 1.0 (inflated). |
| 2 | **Pipeline stages not idempotent** | Kimi (P0), DeepSeek, GLM | GPU crash → Celery redelivers → duplicate transcript rows and scores. Add `ON CONFLICT DO NOTHING` / upsert guards. |
| 3 | **Redis no AOF persistence** | Kimi (P2), DeepSeek | Entire task queue lost on Redis container restart. Enable AOF or switch broker to RabbitMQ. |
| 4 | **Celery chain is brittle** | All four | Stage 6 (Groq) fails → must restart from Stage 1, re-transcribing. No per-stage retry. MVP-acceptable, production-wrong. |

### P1 — Fix Before First Paying Customer

| # | Finding | Reviewers | Fix Required |
|---|---------|-----------|--------------|
| 5 | **Scoring weights hardcoded** | GLM, Opus, Kimi | Every call center has different priorities. Fixed `0.25*P + 0.20*SD...` loses deals. Make tenant-configurable. |
| 6 | **LLM score variance untested** | Opus, Kimi, DeepSeek | Run same call 20x. If ±1.5 points variance → scoring is noise. This test must be done before academic defense. |
| 7 | **Presidio misses South Asian PII** | GLM, Kimi | CNIC numbers, +92 mobile formats, transliterated Urdu names (Mohammad, Syed) not redacted. One leak = contract termination in financial/healthcare. |
| 8 | **No human-in-the-loop** | Opus (strongly), Kimi | No score dispute, no coaching notes, no calibration workflow. "Fire-and-forget pipeline is a demo characteristic." |
| 9 | **Connection pool RLS leak** | DeepSeek (High), Kimi | PgBouncer transaction-pooling drops SET LOCAL between transactions. Session-mode required. |
| 10 | **Per-tenant rate limits missing** | Kimi (P1) | Tenant A can upload 10,000 calls and starve Tenant B of GPU/LLM quota. |

---

## Critical Disagreement — Raw PII to Groq

DeepSeek rated this **Critical**. Kimi didn't flag it. Opus acknowledged but deprioritised.

**Reality check:** `extract_agent_identity` reads first ~500 words of raw transcript before Presidio runs. This text goes to Groq API. Groq doesn't persist prompts per their ToS, but it appears in API logs.

**For South Asian domestic BPO (first market):** GDPR/HIPAA not applicable. Lower risk.
**For UK/EU deployment:** This is a hard blocker. Must fix before entering those markets.
**Interim fix:** Limit raw text sent to extract_agent_identity to first 300 words only (agent intro is always in first 60 seconds). Reduces exposure significantly without architectural rework.

---

## Product Findings (Opus + Kimi — highest product insight)

### Pricing
Both agree: **$5–10 signals student project in B2B.** Price at **$15–20/agent/month**.
Low price doesn't mean accessible, it means unreliable to a BPO operations director.

### Go-to-Market
- South Asian BPO sales are **relationship-driven**, not self-serve credit card
- Self-serve registration page is wrong for this market
- First 3 customers come through **personal network**, not landing page
- Target **domestic-facing call centers** first (telecom, e-commerce, insurance) — less demanding about international compliance

### What Unlocks First Customer (both reviewers agree exactly)
**The "Blind Spot Report":**
1. Get 50 real calls from a BPO (NDA, free)
2. Process them overnight
3. Present: "Your manual QA caught 1 of these 5 worst calls. Here's what happened on the other 4."
4. Ask for 30-day paid pilot

**Build this before any UI redesign, user management, or batch agent.**

### Feature Prioritisation (Opus)
> "The next line of code you write should be the one a customer asked for."
> "Stop building. Go get 50 real calls. Learn what the customer actually needs. Then build that."

The planned feature list (UI redesign, register, user management, agent management, batch upload, Urdu ASR) = 4–6 months solo work **building the wrong things**.

---

## Urdu ASR — Consensus: Not Yet

- **Opus:** Wait for paying customers. Whisper base Urdu is "good enough" to demo.
- **GLM:** Use **LID router + SeamlessM4T** instead of QLoRA fine-tuning. Route pure English to WhisperX, pure Urdu to dedicated Urdu ASR, code-switched to SeamlessM4T.
- **Kimi:** Phase 5 (Urdu ASR) is actually the **strongest moat** — but only if you have customers. Do it after validation.

---

## Batch Upload Agent — Kimi's Specific Improvements

SQLite manifest is weak (locking issues on network mounts, lost on container restart). Replace with:
- **SHA-256 checksum** sent with every upload. API returns `200 Already Processed` if seen before. API = source of truth, not SQLite.
- **asyncio semaphore** for 3–5 concurrent uploads (not sequential)
- **Adaptive backoff** on 429/503 (not fixed delay)
- **inotify/watchdog** for filesystem events (not polling loop)
- **Health endpoint** on :8080 for monitoring

Opus alternative view: **Skip the Docker agent for now.** Build a bulk drag-and-drop upload page in dashboard instead. Ship Docker agent when an enterprise customer asks for it specifically.

---

## Overall Architecture Ratings

| Reviewer | Score | Verdict |
|---------|-------|---------|
| DeepSeek | 6/10 | "Resolve LLM-PII issue, deploy on stable Linux, implement production hardening" |
| GLM | 6.5/10 | "Stop treating pipeline as synchronous script, start treating as distributed event system" |
| Kimi | — | "Fix These First — impressive engine, execution gaps separating FYP from production" |
| Opus | — | "Strong technical prototype, not a product. Gap is workflow tooling, not AI." |

**Composite assessment:** 6–6.5/10. Sound foundation, pre-production execution gaps.

---

## What Changes About The Roadmap

### Add immediately (tiny fixes, high correctness impact):
- Fix `compute_talk_balance` formula → `1 - 2 * abs(agent_ratio - 0.5)`
- Add Redis AOF persistence in `docker-compose.yml`
- Add upsert guards in `write_scores` task

### Add to backlog (post-first customer):
- Tenant-configurable scoring weights
- LLM score variance study (20-run test)
- Custom Presidio recognizers for Pakistani PII (CNIC, +92 mobile)
- Score dispute + coaching notes workflow
- State machine replacing Celery chain (major rework, post-revenue)
- SeamlessM4T LID router (replaces QLoRA fine-tuning approach)

### Deprioritised based on reviews:
- Urdu ASR fine-tuning (wait for customers)
- Batch upload Docker agent (bulk upload page first)
