---
tags: [architecture, deployment, research, pipeda]
status: active
created: 2026-06-23
updated: 2026-06-23
---

# Deployment Options — Call Quality Analytics

> Research document covering viable deployment options for the 7-stage AI pipeline
> (WhisperX + Pyannote GPU inference → FastAPI + PostgreSQL + Redis + MinIO + Celery).
> Target customers: Canadian call centers + South Asian BPOs.
> PIPEDA compliance required for Canadian customers.

> **Pricing caveat:** All dollar figures below are ranges, not quotes. Provider pricing
> changes frequently and varies by commitment, region, and GPU SKU. Every number flagged
> `[verify]` must be confirmed against the provider's live pricing page before it informs
> a budget or a customer commitment.

---

## The pipeline's deployment-relevant shape

What actually constrains where this runs:

- **One GPU-bound stage.** `run_whisperx` (WhisperX large-v2 + Pyannote 3.1 diarization) is
  the only stage that needs a GPU. Everything else — FastAPI, Celery workers, Postgres,
  Redis, MinIO, Presidio redaction, Groq inference call — is CPU-bound and cheap to host.
- **GPU memory footprint is small.** WhisperX (~3GB) + Pyannote (~2GB) ≈ 5GB VRAM. A 16GB
  card is comfortable; an 8GB card works for single-concurrency (proven on the demo laptop).
- **GPU utilization is bursty, not steady.** Inference fires per call upload, runs minutes,
  then idles. This is the single most important cost fact: a 24/7 dedicated GPU is mostly
  paying for idle time. Serverless / on-demand GPU directly targets this.
- **`run_whisperx → gpu_queue` is concurrency=1** (invariant). Throughput scales by adding
  GPU workers, not by overloading one.
- **PII leaves the box only after redaction.** Pipeline order guarantees `pii_redacted=TRUE`
  before `run_groq_inference`, so only redacted text is sent to Groq (US). Raw audio and the
  un-redacted transcript never leave the processing tier. This is the hinge for every PIPEDA
  argument below.

The implication: **the GPU tier and the data tier have completely different optimal homes.**
Splitting them (Option 3 / Option 4) is the natural architecture, not a compromise.

---

## Current State

- **Demo host:** Fahad's laptop — RTX 5060 8GB (Blackwell, GDDR7), 64GB RAM, Windows 10,
  Docker Desktop, dynamic DNS. **No cost.** Used for showing customers, not for production.
- **GPU image:** `Dockerfile.gpu.blackwell` required — CUDA 12.8 + PyTorch 2.7, compiled for
  `sm_120`. The stock `Dockerfile.gpu` (CUDA 12.1, T4/`sm_75`) does **not** run on Blackwell.
- `DIARIZE_DEVICE=cuda` is safe here: WhisperX ~3GB + Pyannote ~2GB ≈ 5GB fits in 8GB GDDR7
  at concurrency=1.
- **Honest limitation:** a laptop on dynamic DNS behind a consumer connection is a demo rig,
  not infrastructure. No uptime guarantee, no data-residency story, no isolation between
  customers. It cannot be the answer for a paying customer, even one.

---

## Option 1 — Local On-Premise (client's own hardware)

**Architecture.** The full Docker Compose stack (app tier + GPU tier) runs inside the
customer's own datacenter or office, on a machine they own with a 16GB+ GPU. Audio never
leaves their premises except for the redacted-text Groq call (and even that can be disabled
if they accept degraded scoring or a local LLM). We ship images and an installer; they
operate the box.

- **Best for:** Large enterprises and BPOs with their own IT, strict data-sovereignty rules,
  or contractual bans on cloud processing. Single-tenant by definition.
- **Estimated cost:** Pre-revenue: $0 to us (customer buys hardware). Early: customer capex
  for a workstation-class GPU box `[verify hardware]`; our cost is support time. Growing:
  scales by selling more boxes, not by our infra spend.
- **PIPEDA posture:** Strongest possible — data never leaves the customer's jurisdiction or
  control. PIPEDA cross-border transfer concerns largely evaporate. Still need a DPA and to
  document that the Groq redacted-text call (if enabled) crosses the border, or disable it.
- **Pros:**
  - Maximal data residency / sovereignty story — closes the hardest compliance objections.
  - No recurring cloud cost for us.
  - No noisy-neighbor / multi-tenant isolation risk.
  - Works in air-gapped or restricted-network environments (sans Groq).
- **Cons:**
  - We lose remote operational control; updates and debugging are hard.
  - High per-deployment touch cost — does not scale to many small customers.
  - GPU driver / CUDA version drift across customer hardware (the Blackwell vs T4 image split
    becomes N image variants).
  - Slow sales cycle (hardware procurement on the customer side).
- **Complexity to deploy:** **High** (per customer).
- **When to choose:** A single large customer with hard sovereignty requirements and their
  own IT, where the contract value justifies bespoke deployment.

---

## Option 2 — Single Cloud VM with GPU

**Architecture.** One cloud VM with an attached GPU runs the entire stack via Docker Compose —
app tier and GPU tier co-located. Simplest possible cloud deployment: lift the demo compose
file onto a rented GPU VM with a real domain and TLS.

- **Best for:** First paying customer(s), pilots, and low call volume where one GPU is plenty.
- **Estimated cost:** Dominated by the GPU VM running 24/7. A 16GB-class GPU VM is the line
  item; CPU/RAM/disk are rounding errors next to it `[verify $/hr per provider — see table]`.
  The waste is real: you pay for the GPU around the clock while it processes calls minutes
  per hour.
- **PIPEDA posture:** Depends entirely on **region**. On a confirmed Canadian-region GPU VM,
  the residency story is clean. On a US/EU GPU (most cheap GPU hosts), raw audio sits outside
  Canada — requires a transfer assessment and customer disclosure; likely a non-starter for
  residency-sensitive Canadian customers.
- **Pros:**
  - Simplest cloud deployment — essentially the demo compose with a domain.
  - Single machine to operate, monitor, back up.
  - Predictable flat monthly cost.
  - No split-tier networking complexity.
- **Cons:**
  - Pays for an idle GPU 24/7 — worst $/call economics of any cloud option.
  - Single point of failure for the whole stack.
  - Confirmed-Canada GPU VMs are scarce and pricey (see provider table).
  - Doesn't scale past one GPU's throughput without re-architecting.
- **Complexity to deploy:** **Low.**
- **When to choose:** First 1–2 customers, or a time-boxed pilot, where simplicity beats
  cost-efficiency and the region question is satisfiable.

---

## Option 3 — Split Tier (CPU app tier + rented GPU)

**Architecture.** This is the project's current Azure design (`docker-compose.app.yml` on a
B4ms CPU node + `docker-compose.gpu.yml` on an NC4as_T4_v3 GPU node). The always-on app tier
(FastAPI, Postgres, Redis, MinIO, Celery beat) lives on a cheap CPU VM in a Canadian region.
GPU workers connect to the same Redis broker and run on a separate GPU VM that can be on-demand
or Spot — spun up under load, torn down when idle. Data services bind to the VNet only
(NSG-restricted), per the local-vs-Azure binding invariant.

- **Best for:** The realistic growth path — 1 to ~20 customers, where you want a Canadian data
  home but refuse to pay for a 24/7 GPU.
- **Estimated cost:** App tier is a steady, modest CPU-VM monthly cost `[verify]`. GPU tier is
  pay-for-what-you-use: on-demand or Spot GPU hours scale with actual call volume `[verify
  $/hr]`. This is materially cheaper than Option 2 whenever the GPU would otherwise idle.
- **PIPEDA posture:** Strong **if both tiers sit in a Canadian region**. The data tier
  (Postgres/MinIO holding audio + transcripts) is the part that matters most for residency;
  keep it Canadian and the GPU tier becomes the only cross-border question. If the GPU is
  rented from a non-Canada provider, raw audio crosses the border transiently for inference —
  this needs the Law 25 transient-processing opinion (Open Questions) and a documented DPA.
- **Pros:**
  - Best cost/compliance balance for the actual growth phase.
  - GPU cost tracks usage, not wall-clock — directly fixes Option 2's idle waste.
  - Data tier residency is decoupled from GPU availability.
  - Matches what's already built; least new engineering.
- **Cons:**
  - Cross-VM networking, broker auth, and Spot-eviction handling add operational complexity.
  - Spot GPUs can be evicted mid-job — needs idempotent retry (idempotency migration helps).
  - If the GPU provider has no Canada region, the transient-transfer compliance question is live.
  - Two things to monitor and secure instead of one.
- **Complexity to deploy:** **Medium.**
- **When to choose:** Default choice once there's a real customer and a real call volume —
  the moment Option 2's idle-GPU bill starts to sting.

---

## Option 4 — Serverless GPU (Modal, RunPod Serverless)

**Architecture.** App tier runs normally on a CPU host; the `run_whisperx` stage is refactored
into a serverless GPU function (Modal, RunPod Serverless, etc.) invoked per call. The platform
cold-starts a GPU container, runs inference, returns the result, and bills by the second.
Zero GPU cost at idle.

- **Best for:** Spiky, unpredictable volume; very early stage where you want near-zero fixed
  GPU cost; or bursting above the split-tier GPU's capacity.
- **Estimated cost:** Lowest fixed cost — you pay only for inference seconds `[verify per-second
  GPU rate]`. **But** providers apply regional multipliers (Modal documents a higher multiplier
  for non-US regions — treat as ~2.5x `[verify exact multiplier]`), and cold starts add latency
  and some billed warmup. Cheapest at low/spiky volume; can lose to a dedicated GPU at high
  steady volume.
- **PIPEDA posture:** **Weakest by default.** Serverless GPU providers generally do not offer a
  confirmed Canadian region, so raw audio is processed in US/EU. Viable for Canadian customers
  only with (a) a provider that contractually offers a Canada region, or (b) a Law 25 legal
  opinion that transient, non-retained GPU processing outside Canada is acceptable with proper
  disclosure. Fine for South-Asia-only customers if PIPEDA doesn't apply to them (Open Question).
- **Pros:**
  - Near-zero GPU cost at idle — best economics for low or bursty volume.
  - No GPU VM to operate, patch, or right-size.
  - Scales horizontally to many concurrent calls automatically.
  - Good fit as an overflow/burst layer on top of Option 3.
- **Cons:**
  - Cold-start latency and warmup billing on infrequent traffic.
  - Region/residency story is the weakest — usually no Canadian DC.
  - Requires refactoring `run_whisperx` out of the Celery worker into a function boundary.
  - Regional multipliers and per-second math make cost forecasting harder.
- **Complexity to deploy:** **Medium–High** (the refactor is the cost).
- **When to choose:** Very early, volume is spiky and small, and customers are not
  residency-sensitive — or later as a burst layer above the split tier.

---

## Option 5 — Managed Cloud (Azure / AWS / GCP full stack)

**Architecture.** Replace self-managed containers with managed services: managed Postgres
(Azure Database for PostgreSQL / RDS / Cloud SQL), managed Redis, object storage (Blob / S3 /
GCS) in place of MinIO, and GPU VMs or managed GPU compute for inference. App tier on managed
container hosting (Container Apps / ECS / Cloud Run). Full hyperscaler stack in a Canadian region.

- **Best for:** Scale (20+ customers), enterprise procurement that demands a hyperscaler name,
  and teams that want to trade money for less ops burden.
- **Estimated cost:** Highest fixed cost — managed-service premiums on every component plus GPU
  compute `[verify]`. Justified only when ops time saved and enterprise trust are worth more
  than the premium. Overkill pre-revenue.
- **PIPEDA posture:** Strongest paper trail — Azure Canada Central, AWS ca-central-1, and GCP
  Montréal all offer Canadian regions with signed DPAs, data-residency commitments, and
  compliance certifications customers' legal teams recognize. Easiest to defend in enterprise
  procurement.
- **Pros:**
  - Best enterprise-trust and compliance documentation story.
  - Managed services remove most ops/patching/backup burden.
  - Confirmed Canadian regions with formal residency guarantees.
  - Scales cleanly to many tenants.
- **Cons:**
  - Highest cost; managed-service premiums add up fast.
  - GPU quota friction — Azure (and others) often deny GPU quota on new/unproven accounts
    (already observed; see Open Questions).
  - Most migration effort (MinIO→Blob/S3, self-managed→managed Postgres/Redis).
  - Easy to over-provision and overspend before there's revenue to justify it.
- **Complexity to deploy:** **High.**
- **When to choose:** At real scale, or when a specific enterprise customer's procurement
  requires a named hyperscaler and formal compliance artifacts.

---

## Provider Comparison Table

> $/hr figures are **placeholders pending verification** against each provider's live pricing
> page. Do not quote these to a customer or put them in a budget without confirming.

| Provider | Region | GPU Available | Canadian DC | Approx $/hr (16GB+ VRAM) | PIPEDA notes | Verdict |
|---|---|---|---|---|---|---|
| OVHcloud | Beauharnois, Québec | No (app tier only) | ✅ Yes | n/a (CPU) | Canadian region → clean residency for data/app tier | **Good app-tier home** in Canada; pair with external GPU |
| DigitalOcean | Toronto (TOR1) | No (app tier only) | ✅ Yes | n/a (CPU) | Canadian region; simple, well-documented | **Good app-tier home**; no GPU |
| Vultr | Toronto | No (app tier only) | ✅ Yes | n/a (CPU) | Canadian region | **Viable app-tier**; no GPU |
| RunPod | Canada claim **unverified** | ✅ GPU | ⚠️ Unverified — see `Lessons/runpod-canada-region-unverified` | `[verify]` | Sources contradict on Canada region; do **not** assume residency | **GPU candidate, region must be verified** before any residency-sensitive use |
| Vast.ai | Marketplace (global) | ✅ GPU | ❌ No guaranteed Canada DC | `[verify]` (often cheapest) | Marketplace hosts, no residency guarantee | **Cheapest GPU; not for residency-sensitive data** |
| Paperspace | US/EU | ✅ GPU | ❌ Not confirmed | `[verify]` | No confirmed Canada DC | GPU option **only if residency not required** |
| Modal | US/EU (serverless) | ✅ GPU (serverless) | ❌ No Canada DC | per-second + **~2.5x non-US multiplier** `[verify]` | No Canada region; transient processing → needs Law 25 opinion | **Best idle economics; weakest residency** |
| Azure Canada Central | Canada Central | ✅ GPU (NC-series) | ✅ Yes | `[verify]` | Full residency + DPA + certs; **GPU quota denied on new accounts** | **Best compliance; fight for GPU quota** |
| AWS ca-central-1 | Canada (Central) | ✅ GPU | ✅ Yes | `[verify]` | Full residency + DPA + certs | **Strong managed/compliance option** |
| Hetzner | Germany/Finland (EU only) | ✅/limited GPU | ❌ EU only | `[verify]` (cheap) | EU-only; **not viable for Canadian PIPEDA residency** | **Excluded** for Canadian customers |

**Pattern that falls out of the table:** the cheap, Canadian-region hosts (OVH Québec, DO
Toronto, Vultr Toronto) are **CPU-only**. The GPU hosts either have **no confirmed Canada
region** (Vast, Paperspace, Modal, RunPod-unverified) or are the **expensive hyperscalers**
(Azure/AWS). This is exactly why the split tier (Option 3) exists: put the data-bearing app
tier on a cheap Canadian CPU host, and solve the GPU-region question separately.

---

## Decision Framework

**By customer count:**

- **0 customers (now):** Demo laptop. Spend nothing. (See Current Recommendation.)
- **1–5 customers:** Option 2 (single Canadian GPU VM) for simplicity, or Option 3 if GPU idle
  cost already hurts. Avoid managed cloud — premature.
- **5–20 customers:** Option 3 (split tier) is the sweet spot — Canadian CPU app tier +
  on-demand/Spot GPU. Add Option 4 as a burst layer if volume is spiky.
- **20+ customers:** Option 5 (managed cloud) for ops relief and enterprise trust, or a hardened
  Option 3 if cost discipline matters more than the hyperscaler name.

**By customer location:**

- **Canada:** Residency pressure is real. Data tier must be in a Canadian region (OVH/DO/Vultr/
  Azure/AWS). GPU region is the open question — verify or get the Law 25 opinion.
- **South Asia only:** If PIPEDA doesn't apply (Open Question), residency constraints relax —
  cheapest GPU (Vast, Modal, RunPod anywhere) becomes viable. Latency to a nearer region matters
  more than jurisdiction.
- **Both:** Run per-region deployments, or default to a Canadian data tier (the stricter regime)
  and segment GPU by customer.

**By data-residency requirement:**

- **Hard residency guarantee required:** Option 1 (on-prem) or Option 5 (hyperscaler Canadian
  region) only. Serverless/marketplace GPU is out.
- **No hard guarantee:** Any option; optimize for cost (Option 3/4).

**By monthly infra budget:**

- **~$0 fixed:** Demo laptop now; Option 4 serverless when there's a customer.
- **Low fixed:** Option 3 — cheap Canadian CPU tier + usage-billed GPU.
- **Cost-insensitive / enterprise-funded:** Option 5.

---

## Current Recommendation (pre-first-customer)

**Uncomfortable truth first:** there is no infrastructure decision to make right now, and making
one would be a mistake. With zero paying customers, every dollar of fixed cloud spend and every
hour of migration work is speculative. The demo laptop, despite being a laptop on dynamic DNS,
is the correct host for *showing* the product — it costs nothing and works.

**What makes sense right now:**

1. **Keep the demo on Fahad's laptop.** It's free and sufficient for sales demos. Its
   limitations (no uptime, no residency) don't matter until someone is paying.
2. **Do the cheap verification work now** (Open Questions below) so you're not scrambling when a
   customer appears. Confirming RunPod's Canada region, Groq's ZDR status, and the Law 25
   position costs only time and de-risks the first real deployment.
3. **Pre-design for Option 3, don't build it yet.** The split-tier compose files already exist.
   Keep them current. Do not provision a paid Canadian VM until a signed customer justifies it.

**What makes sense at scale (for the file, not for today):** Option 3 as the workhorse (Canadian
CPU app tier + on-demand/Spot GPU), Option 4 as a burst layer, and Option 5 reserved for the
first enterprise customer whose procurement demands a hyperscaler name and formal compliance
artifacts. Option 1 (on-prem) only for a specific large, sovereignty-bound account.

**The one thing to decide before the first paying customer:** where the *data tier* lives. That's
the residency-defining choice. A Canadian CPU host (OVH Québec / DO Toronto) is cheap and
forecloses the hardest PIPEDA objection. The GPU-region question can be answered per-customer.

---

## Open Questions

These must be verified before committing to any option for a real customer:

- **RunPod Canada region.** Unresolved and contradictory (`Lessons/runpod-canada-region-unverified`).
  Verify directly against RunPod's live datacenter list or by spinning up a test pod — not from
  cached search results, which go stale. Blocks using RunPod for any residency-sensitive customer.
- **Groq ZDR (Zero Data Retention) status.** Only redacted text reaches Groq, but confirm whether
  Groq retains or trains on prompts, and whether a ZDR/enterprise tier with a signed DPA is
  available. Determines whether the Groq call needs disclosure or disabling for strict customers.
- **Law 25 (Québec) legal opinion on transient GPU processing.** If raw audio is processed
  transiently on a non-Canada GPU (Options 3/4), is that an acceptable cross-border transfer under
  Law 25 with proper disclosure and no retention? This single opinion unlocks (or kills) the cheap
  GPU options for Canadian customers. Needs a privacy lawyer, not a guess.
- **Do South Asian BPOs actually require PIPEDA compliance?** PIPEDA is Canadian law. A South-Asian
  BPO may be in scope only if it processes Canadian personal data on behalf of a Canadian client
  (and then often via the client's PIPEDA obligations flowing down by contract). If a South-Asia
  customer serves only non-Canadian end users, PIPEDA likely doesn't apply and the cheapest GPU
  anywhere becomes viable. Confirm per customer — this materially changes their deployment options.
- **Azure GPU quota on new accounts.** Already observed as a blocker. Confirm whether GPU quota can
  be obtained on the intended subscription before betting a deployment on Option 5/Azure GPU.
