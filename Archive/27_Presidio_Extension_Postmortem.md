---
tags: [phase-5, presidio, pii, ai-pipeline]
date: 2026-04-17
status: complete
---

# 27 — Presidio Extension Postmortem

> Previous: [[26_Audio_Testing_Postmortem]]
> See [[CONTEXT]] for PII invariants · [[09_Phase2.2_Postmortem]] for original Presidio setup

---

## What Was Built

Extended Microsoft Presidio with three custom regex recognizers to catch telephony-specific PII
that the default NLP engine misses. Gaps identified from real audio testing in [[26_Audio_Testing_Postmortem]].

## New Recognizers Added

| Entity | Pattern | Context Words | Catches |
|---|---|---|---|
| `US_SSN` (last-4) | `(?<=last\s{0,10}four\D{0,20})\d{4}\b` | social, ssn, security, last four | `5528` after "last four digits of your social security number" |
| `ZIP_CODE` | `\b\d{5}(?:-\d{4})?\b` | zip, postal, billing, shipping, address | `59714` after "billing zip code" |
| `ACCOUNT_NUMBER` | `\b\d{3}-\d{3}-\d{3}\b` | account, number, member, id | `326-143-411` after "account number" |

## Context-Based Matching Design

Recognizers use context words to avoid false positives. A bare `5528` won't trigger redaction.
`last four digits... 5528` will. This prevents false positives on prices, dates, and reference numbers.

## Files Modified

- `backend/app/services/presidio_service.py` — 3 new recognizers, 2 new entity types, 2 new operators

## Commit

`feat: extend Presidio with SSN last-4, zip code, and account number recognizers`

## Known Remaining Gaps

- Pakistani CNIC numbers (XXXXX-XXXXXXX-X format) — future work
- Pakistani mobile numbers (+92 3XX XXXXXXX) — future work
- 4-digit PINs without context
- Long account numbers (12+ digits) without "account" keyword

## Invariants Confirmed

- Raw PII never hits PostgreSQL ✅
- Presidio gate runs before every DB write ✅
- New recognizers are context-aware — no false positives on prices/dates ✅
- `pii_redacted = TRUE` still set after redaction ✅
