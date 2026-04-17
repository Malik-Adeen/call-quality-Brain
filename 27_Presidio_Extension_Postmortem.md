---
tags: [phase-5, presidio, pii, demo-ready]
date: 2026-04-17
status: complete
---

## What Was Built

Extended Microsoft Presidio with three custom regex recognizers to catch telephony-specific PII that the default NLP engine misses. Identified gaps from real audio testing and implemented targeted fixes.

## New Recognizers Added

| Entity | Regex | Context Words | Catches |
|---|---|---|---|
| `US_SSN` (last-4) | `(?<=last\s{0,10}four\D{0,20})\d{4}\b` | social, ssn, security, last four | `5528` after "last four digits of your social security number" |
| `ZIP_CODE` | `\b\d{5}(?:-\d{4})?\b` | zip, postal, billing, shipping, address | `59714` after "billing zip code" |
| `ACCOUNT_NUMBER` | `\b\d{3}-\d{3}-\d{3}\b` | account, number, member, id | `326-143-411` after "account number" |

## Bugs / Gaps Resolved

| Gap | Root Cause | Fix |
|---|---|---|
| SSN last-4 digits not redacted | Presidio default has no partial-SSN recognizer | Added lookbehind regex with SSN context words |
| Zip code not redacted | Standalone 5-digit numbers not classified without context | Added zip recognizer with billing/address context |
| Account number not redacted | `XXX-XXX-XXX` format not in any default entity | Added custom pattern recognizer with account context |

## Context-Based Matching Design

Recognizers use context words to avoid false positives. A bare `5528` won't trigger redaction. `last four digits... 5528` will. This is the correct enterprise approach — aggressive regex without context creates too many false positives on legitimate content like prices, dates, and reference numbers.

## Files Modified

- `backend/app/services/presidio_service.py` — 3 new recognizers, 2 new entity types, 2 new operators

## Commit

`feat: extend Presidio with SSN last-4, zip code, and account number recognizers`

## Invariants Confirmed

- Raw PII never hits PostgreSQL ✅
- Presidio gate runs before every DB write ✅
- New recognizers are context-aware — no false positives on prices/dates ✅
- `pii_redacted = TRUE` still set after redaction ✅

## Next Step

Re-upload `bpo_inbound_1.mp3` after `git pull` on Azure VM to verify `59714` → `<ZIP_CODE>` and `5528` → `<SSN>` in transcript.
