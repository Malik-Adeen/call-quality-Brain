# Session Handoff — 2026-07-15 (session 2) — Fahad's Demo Machine

> Windows/WSL2, Docker Desktop, RTX 5060 Blackwell. Distinct from 69_Session_Handoff_2026-07-15.md
> (same calendar date, different session — that one is master/uv migration; this one is
> deploy/fahad-demo). Precedent for same-date numbered handoffs: Archive/36 + Archive/38, both
> 2026-05-02.

## COMMITTED AND PUSHED to deploy/fahad-demo (96e5705 → e2cecf7, plus 28ee65d second half)

Nothing cross-committed to master.

- `99c7026` port: `GROQ_INFERENCE_MODEL` env var + structured output (hand-ported from master `9143a8e` — branches had diverged structurally, cherry-pick was not viable)
- `b576335` docs: describe `GROQ_INFERENCE_MODEL` mechanism, drop hardcoded model
- `ae3d8cd` fix: retry Groq on `json_validate_failed`; temperature 0.0, max_tokens 4000
- `2760c84` fix: revert temperature to 0.2, max_retries 4 (0.0 turned out to be actively harmful — see Bug 3 below)
- `e2cecf7` feat: batch drag-and-drop upload, frontend only
- `28ee65d` fix: `infra/docker-compose.app.yml:131` bind nginx port 80 to `127.0.0.1` instead of `0.0.0.0` (second half of this session — see STEP 3 below)

## STEP 0 — Groq key crisis (done)

Fahad's `infra/.env` held `gsk_5t...` — a **third** key, neither the revoked `gsk_q7...` nor the
dev machine's `gsk_VG...`. 401 on test call. Replaced with `gsk_VG...` (56 chars, verified HTTP 200
against `/v1/models`).

**Root cause of "why was scoring broken":** the stack is split across compose files with different
`--env-file` args, so the three running containers held three different keys:

| Container | Compose file | `--env-file` |
|---|---|---|
| `cq_api` | `docker-compose.app.yml` | `infra/.env.prod` |
| `cq_worker_gpu` | `docker-compose.gpu.yml` | (none — reads `.env` by default) |
| `cq_worker_io` | `docker-compose.app.yml` | `infra/.env.prod` |

Editing `infra/.env` alone reaches none of them reliably. **Always verify with**
`docker exec <container> printenv GROQ_API_KEY | cut -c1-6` — never by reading files.

**NEW FINDING (corrects existing vault docs — see "Correction to the record" below):**
`--env-file` overrides the default `.env` load for that compose invocation. For the app.yml stack
specifically, `.env.prod` wins because it's explicitly passed as `--env-file`; `.env` does not
silently win here.

**Naming trap:** container `cq_worker_gpu`'s compose *service* name is `worker_cpu` in
`docker-compose.gpu.yml`. `docker compose ... up -d worker_gpu` → "no such service".

**Orphan-container warning is expected** — same Compose project name, different compose files.
**Never run `--remove-orphans`** — the "orphans" it would remove are postgres/redis/minio.

`MODEL_CACHE_HF` / `MODEL_CACHE_TORCH` were defined in **no** env file (only `.env.example`).
Volume spec resolved to `:/root/.cache/huggingface` (empty host path) → invalid volume spec error.
Added both to `infra/.env`. Consequence of the gap: model cache was empty going into this session,
so WhisperX re-downloaded ~360MB at task time.

## STEP 1 — Model migration (done, verified)

Branches had diverged structurally: master has `pipeline/stages/*`, deploy/fahad-demo still has
the monolithic `backend/app/pipeline/tasks.py`. Cherry-pick of `9143a8e` was not viable — ported by
hand instead.

- `llm_client.py` taken wholesale from `origin/master`.
- `tasks.py`: 2 edits — model string (~line 170), deferred import + `response_format` arg (~line 375).

**Verified:** 4× HTTP 200, `inference success via groq` log line, model `openai/gpt-oss-120b`.

## STEP 2 — Batch upload (done)

`frontend/src/pages/BatchUpload.tsx`. Zero backend changes, zero new npm deps.

- Native HTML5 drag-and-drop + inline concurrency limiter (rejected `react-dropzone` /
  `p-limit` — package.json churn forces an nginx image rebuild on Fahad's box for no gain).
- Concurrency 3. **PERF note:** buffers the whole file in memory before the size check.
- Subscribes to the existing socket via `useWsStore((s) => s.lastEvent)` — `App.tsx` owns the
  only WebSocket. Chips flip on `call_complete` / `pipeline_error`, both carry `call_id`.
- `processing` renders as "IN QUEUE" — GPU worker is `--concurrency=1`, files score serially.
- Wired: `App.tsx` import + route (same `ProtectedLayout`/`RoleGuard` as `/upload`) + `PAGE_TITLES`
  + Sidebar icon button (Layers) beside NEW ANALYSIS, same role guard.
- **Verified:** 3 files dropped → 3 chips → all reached `complete` via WS.
- Known cosmetic gap: "Start 0 Evaluations" button should hide when `queuedCount === 0`.

## STEP 3 — Cloudflare Tunnel (call-qa.tech) — DONE, verified

Second half of this session. Supersedes the "Next session — Cloudflare Tunnel" plan below (kept
for reference; every numbered step in it is now done).

- `call-qa.tech` active on Cloudflare (free plan), account `Adeen4rizwan@gmail.com`. Nameservers
  `hazel`/`melnicoff.ns.cloudflare.com`, delegated at the OrderBox-based registrar. Propagated in
  ~15 min.
- No DNS records added manually — `cloudflared tunnel route dns` created the CNAME.
- Tunnel `call-qa-tech`, UUID `73cd348d-039a-41fd-a8cf-c272f9a22acf`. Config:
  `C:\Users\fahad\.cloudflared\config.yml` → ingress hostname `call-qa.tech` → service
  `http://localhost:80` (`cq_nginx` via Docker Desktop).
- **Verified:** page loads, login works, WebSocket accepted through the tunnel (`cq_api` logs show
  `WS /ws/{user_id} [accepted]`), call scored end-to-end, row flipped to `complete` without a
  refresh. Survives reboot.
- `CORS_ORIGINS` in `infra/.env.prod` is now `https://call-qa.tech` only — this also strips the
  `http://localhost:5173` Vite-dev origin flagged as "Strip before demo" in Cleanup owed below.
  **Closes that cleanup item.**
- `infra/docker-compose.app.yml:131` `"0.0.0.0:80:80"` → `"127.0.0.1:80:80"`. Committed `28ee65d`,
  pushed. This was the last `0.0.0.0`-bound port on the stack — the "(except nginx port 80)"
  exception in INVARIANTS.md's port rule is now closed; see INVARIANTS.md.
- Tailscale Funnel was **already off** (`tailscale funnel status` → "No serve config") — the
  original plan's step 7 ("decommission only after Cloudflare verified") was moot, nothing to
  decommission. `call-qa.tech` is now the live public URL; the Tailscale Funnel URL
  (`https://deltaroot-pt-lp.tailb8d983.ts.net`) recorded in 65_Session_Handoff_2026-06-28.md and
  LOG.md's 2026-06-28 entry is stale — those are historical records, left as-is, but do not treat
  that URL as current anywhere else.

### NEW INVARIANT — cloudflared Windows service (cost the most time this session)

`cloudflared service install` on Windows (v2026.7.2) installs the service with **no arguments** —
bare `cloudflared.exe`, no `--config`, no `tunnel run`. It starts, has nothing to do, exits, and
crash-loops every 20s. Application event log shows only "service starting"; System log only
"terminated unexpectedly" — no cause is ever logged. Reinstalling after the config exists does
**not** help, nor does `--config X service install`, nor copying `config.yml` into LocalSystem's
profile (`C:\Windows\System32\config\systemprofile\.cloudflared\`). `sc.exe config binPath=` fails
under PowerShell quoting.

**Working fix** — set the service args via the registry directly:

```powershell
$bin = '"C:\Program Files (x86)\cloudflared\cloudflared.exe" --config "C:\Users\fahad\.cloudflared\config.yml" tunnel run call-qa-tech'
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\cloudflared' -Name ImagePath -Value $bin
Restart-Service cloudflared
```

Verify with `(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\cloudflared').ImagePath`.

Anyone who reinstalls or upgrades the service will **silently regress** to bare args. The
token-based install path (which does write correct args) requires activating Zero Trust, which
demands a payment card — rejected. Promoted to INVARIANTS.md — this is a re-breakable rule, not a
one-off session note.

### Gotchas worth recording

- Fahad's box had a pre-existing `cert.pem` for a **different** Cloudflare account (the `axion`
  tunnel, `D:\claude\axion`). `tunnel route dns` silently created `call-qa.tech.harba.net` instead
  of `call-qa.tech`. Always check the CNAME in the `route dns` output — a suffixed hostname means
  wrong-account cert. Fix: move `cert.pem` aside, re-run `tunnel login`, pick the right account.
  Orphan tunnel `call-qa` (`d568bb22`) still exists on the `harba.net` account — harmless, delete
  from that dashboard when convenient.
- Docker Desktop returns `"ports are not available ... /forwards/expose returned unexpected
  status: 500"` when rebinding a published port. `compose up -d` is not enough; needs
  `compose rm -sf <service>` then `up -d` (scoped to one service — **not** `--force-recreate`).
- Fahad's machine also runs a Caddy (`D:\claude\axion\infrastructure\https\caddy.exe`, PID-varies)
  LISTENING on `192.168.8.10:8000` with live external connections from non-LAN IPs. Unrelated to
  this project. Flagged to Fahad; not ours to touch.
- Zed SSH-remotes into WSL2, not Windows (already noted below) — Claude Code specifically did not
  work over that SSH session this pass either.

### Correction to the "0.0 talk_balance" entry (Bug 6 above)

Confirmed non-issue for the pipeline itself. Real calls produce nonzero `talk_balance_score`
(observed `0.3196` / `0.5097` / `0.2903` this session). The all-AGENT collapse remains a gTTS
fixture artifact (see Bug 5's correction above) — `scripts/generate_test_audio.py` uses one voice
with accent variants (`tld` `"com"` vs `"com.au"`), which pyannote correctly reads as a single
speaker. The open UI risk from Bug 6 stands unchanged and unfixed: when diarization legitimately
returns one speaker, `talk_balance_score` is `0.0` but the UI still renders a normal-looking
overall score. This is a product decision, not a bug to fix blind.

## Bugs found this session — all exist on master too, fixed only on deploy/fahad-demo

1. **`run_inference` retry loop is dead code.** Introduced by `9143a8e`. The loop logs "retrying"
   then `break`s to the next provider — `max_retries` never applied. Fix: `continue` before the
   `break` when `attempt < max_retries - 1`. **Needs a scoped port to master.**
2. **gpt-oss + `response_format` strict:true + `reasoning_effort:"low"` → ~40% `json_validate_failed`.**
   Measured 2/5 failures on identical input. Model emits literal `0. nine` instead of `0.9`; Groq's
   schema validator rejects it. `reasoning_effort:"low"` is the suspect — added untested by
   `9143a8e`. `medium` is **untested**: all 5 probes returned 429 (TPM exhausted). Retest on the
   dev box. Current mitigation is `max_retries=4` → ~2.6% residual failure — a mitigation, not a fix.
3. **`temperature:0.0` is actively harmful here** — greedy decoding makes the fumble deterministic
   and renders retries useless (one call failed 4/4 identically). Reverted to 0.2. New invariant
   candidate: retry-based recovery requires nonzero temperature.
4. **`OPENROUTER_API_KEY` invalid on the demo machine** (401). There is no fallback leg. Every
   `json_validate_failed` that exhausts retries is a hard call failure. **Fix before demo.**
5. **CORRECTED — diarization collapse is a test-fixture defect, not a Blackwell/pyannote bug.**
   Originally logged as "diarization collapse on Blackwell" and flagged the biggest demo risk.
   Re-examined: same worker, same GPU, same run — `agent_identity_priya.mp3` diarized correctly
   (AGENT and CUSTOMER both present) while `agent_identity_marcus.mp3` collapsed to all-AGENT.
   Per-file, not per-machine — **Blackwell is exonerated.** Root cause: `scripts/generate_test_audio.py`
   generates fixtures with gTTS using accent variants only (`tld="com"` for agent, `tld="com.au"`
   for customer) — same synthesis engine, same underlying voice. Pyannote's speaker embeddings
   cannot reliably separate them; when it reports one speaker on these fixtures, it is CORRECT. The
   `std(): degrees of freedom is <= 0` pyannote warning is consistent with single-speaker input — a
   symptom, not a cause. Real customer audio (two humans) will not reproduce this; **not a
   production bug.** Filed as a known test-data limitation, not a demo risk.
6. **NEW — talk_balance_score silently goes structurally meaningless on single-speaker diarization.**
   When diarization legitimately yields one speaker (confirmed reproducible with the gTTS fixtures
   above, and possible on any real call pyannote fails to split), `talk_balance_score` is 0.0 — but
   the UI still renders a normal-looking overall score (76-82%). The zero is indistinguishable from
   a real "agent never let the customer talk" finding; a structurally meaningless metric is
   invisible to the viewer. **Open, unfixed.** Replaces item 5 as the actual demo risk in this
   category.
7. **`UploadCall.tsx` hardcodes `MAX_FILE_SIZE = 50MB`** (×3 call sites) but `calls.py:347` allows
   100MB. Frontend rejects files the backend accepts. Not fixed this session —
   `BatchUpload.tsx` uses the correct 100MB.
8. `ae3d8cd`'s commit message claims temperature 0.0; `2760c84` reverts it. Message is stale in
   history (informational only, not worth amending).

## Environment gotchas (Fahad's box)

- No Node in WSL initially. Frontend builds **inside** the nginx image (`context: ../frontend`),
  so there is no HMR — every TSX change costs a full `docker compose build nginx`. Frontend work
  belongs on the dev box.
- Repo lives on `/mnt/c` → all files are CRLF. `git config core.autocrlf true` is **required** on
  this machine; without it, git reports 115 files / ~57,420 lines changed (whitespace only) and a
  `git add -A` would push a catastrophic diff. `autocrlf=false` made it worse, not better.
- Zed SSH-remotes into the WSL2 distro, not Windows — Zed's remote server is Linux/macOS only.

## Cleanup owed on Fahad's machine

- SSH key `~/.ssh/id_ed25519` (Adeen's GitHub write access, no passphrase) is still on his laptop
  and registered at github.com/settings/keys. **Remove it.** Use a repo deploy key next time.
- ~~`CORS_ORIGINS` in `infra/.env.prod` now includes `http://localhost:5173` (added for Vite dev).
  Strip before demo.~~ **DONE (STEP 3, this session)** — `CORS_ORIGINS` is now `https://call-qa.tech`
  only.
- `infra/.env`'s `CORS_ORIGINS` was `http://adeen.dynu.net` — confirmed dead config, `cq_api`
  reads `.env.prod`. Left as-is.
- `MINIO_IMAGE_TAG=latest` in `.env.prod` (unpinned) vs. a pinned RELEASE tag in `.env`.

## Correction to the record (flagging, not silently overwriting)

The session notes going into this write-up said: *"NEW INVARIANT: `--env-file` overrides the
default `.env` load... The existing note that '.env silently wins over .env.prod' is FALSE for the
app.yml stack. Correct INVARIANTS.md."* **INVARIANTS.md does not actually contain this claim** —
checked the full file this session, no `.env`/`.env.prod` precedence statement exists there. The
wrong claim actually lives in two places:

- `KNOWN_ISSUES.md`, P2 section, "infra/.env secret management" — *"`.env` silently wins on docker
  compose when both files are present."*
- `LOG.md`, 2026-06-25 entry — *"`.env` silently overrides `.env.prod` when both present in docker
  compose."*

Both are corrected in this pass (see KNOWN_ISSUES.md diff). The real mechanism: precedence is
per-invocation, driven by whichever `--env-file` flag (if any) that container's compose command
uses — see the table in STEP 0 above. There is no single global rule; it must be checked per
service. LOG.md's 2026-06-25 entry is left as historical record (not rewritten) with a forward
pointer added.

## Next session — Cloudflare Tunnel (call-qa.tech) — DONE, see STEP 3 above

Original plan, kept for reference. Every step below is now done — see STEP 3 above for the
verified outcome and the gotchas that came up executing it.

1. Confirm `call-qa.tech` is delegated to Cloudflare.
2. Decide `cloudflared` as a Compose service vs. a Windows service. The machine already has
   PowerShell/Task Scheduler startup automation → a Windows service survives Docker Desktop
   restarts, but splits the stack across two lifecycle managers. Pick one and record it.
3. Tunnel terminates at `cq_nginx`. `nginx.conf` already has correct WS proxying
   (Upgrade/Connection headers, 86400s timeouts) — verified this session.
4. `CORS_ORIGINS` → `https://call-qa.tech` in `infra/.env.prod`, then recreate `cq_api`.
5. Verify WS end-to-end through the tunnel — batch upload chips depend on `call_complete`.
6. Confirm the MinIO webhook (`POST /internal/minio-event`) still resolves inside the Docker network.
7. Only after Cloudflare is verified: decommission Tailscale Funnel
   (`https://deltaroot-pt-lp.tailb8d983.ts.net`).
8. Same pass: move internal ports `0.0.0.0` → `127.0.0.1` (partial fix for the ports-exposure item
   in KNOWN_ISSUES.md).

## STILL OPEN (carried from 69_Session_Handoff_2026-07-15.md)

- HF_TOKEN rotation — exposed in plaintext earlier session, still not rotated.
- Old GROQ_API_KEY (`gsk_q7...`) revocation in the Groq console — new key is in place everywhere,
  but the old one was never confirmed revoked. This session found a **third** stray key
  (`gsk_5t...`) on Fahad's box too, now replaced — worth an explicit sweep of the Groq console's
  active-keys list rather than assuming only one old key is floating around.
- Blackwell real-inference verification (whisperx@CT2 4.8.0, cuDNN 9) — **resolved, not open.**
  The diarization collapse originally attributed here (Bug 5 above) was root-caused this pass to a
  gTTS test-fixture defect (`scripts/generate_test_audio.py` synthesizes agent/customer with the
  same voice, different accent `tld` only), unrelated to the CT2/cuDNN migration. Blackwell
  real-inference itself has no outstanding diarization question. The actual open item is Bug 6
  above (talk_balance_score masking on single-speaker diarization).

## STILL OPEN (carried forward after STEP 3 — Cloudflare Tunnel session)

- **`OPENROUTER_API_KEY` is 401 on the demo box. No fallback leg.** Every exhausted-retry
  `json_validate_failed` is a hard call failure. **HIGHEST remaining demo risk** — Cloudflare
  Tunnel removed the networking/access risk, this is now the top item.
- `gpt-oss` `reasoning_effort:"medium"` never measured (429 TPM on all 5 probes). Retest on the
  dev box.
- Port 3 fixes to master (scoped, separate reviews): dead retry loop, temperature revert.
- HF_TOKEN was exposed in plaintext during this session — rotate per the existing hard rule.
- JWTs appear in full in `cq_api` logs (WS token is a query param, not a header). Hardening item.
- `infra/.env` and `infra/.env.prod` are diverged again (`.env` still has the dead
  `http://adeen.dynu.net` CORS origin). `cq_api` reads `.env.prod`, so this is cosmetic —
  but the "keep them in sync" rule is currently violated.
