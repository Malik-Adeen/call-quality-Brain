# Session Handoff — 2026-07-04

## Master HEAD
c952b11 — chore: router/service split, pipeline stages split, frontend component decomposition

## Branch status
- chore/cleanup-2026-06 merged/pushed to master
- Worktree at .cq-master-wt still exists — remove when convenient
- deploy/fahad-demo: still at 96e5705, intentionally untouched, separate env

## What changed in c952b11
- routers/calls.py 477→155
- agents.py 499→127
- platform.py 539→122
- pipeline/tasks.py 547→17 (7 stages split into pipeline/stages/*)
- Overview.tsx 632→148
- CallDetailPanel.tsx 446→193
- App.css deleted
- graphify-out untracked
- conftest.py localhost→cq_postgres

## CT2 pin
176c950 — ctranslate2==4.8.0 pinned in Dockerfile.gpu.blackwell, spaCy wheel from GitHub URL

## Test baseline
24 pass / 3 fail / 6 error — pre-existing, not a regression

## Cloudflare Tunnel decision
call-qa.tech replacing Tailscale Funnel on Fahad's machine, not yet configured

## Next session order
1. uv migration (3 groups: api/io, gpu-shared, per-Dockerfile torch overrides)
2. CI fix (main→master, drop --reload)
3. Cloudflare Tunnel setup
4. CI/CD self-hosted runner (security decision needed first)
5. Batch upload feature
