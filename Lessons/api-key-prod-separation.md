---
tags:
  - lesson
  - security
  - todo
---

# API Key Prod/Dev Separation — Do Not Skip

**As of 2026-06-21:** `GROQ_API_KEY` and `OPENROUTER_API_KEY` in `infra/.env.prod` are identical to the values in `infra/.env` (dev). One shared key per service, no prod/dev separation.

Acceptable for demo/trial phase with synthetic or low-volume test data. MUST be rotated to dedicated prod keys before processing any real customer call audio — do not let this slip past first paying customer.

**Why this matters:** Shared keys mean a rate-limit hit in prod affects dev and vice versa, usage is unattributable, and a compromised key takes down both environments simultaneously. Groq and OpenRouter both support multiple API keys per account.

**How to apply:** Before onboarding the first paying tenant, create separate Groq and OpenRouter API keys scoped to production, replace the values in `infra/.env.prod` only, and redeploy the app tier.
