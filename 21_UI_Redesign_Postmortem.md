---
tags: [phase-3, ui, redesign, frontend, design-system]
date: 2026-04-14
status: complete
---

> Previous: [[17_Phase3_Frontend]] · Next: [[23_Phase4_Postmortem]] · Index: [[00_Master_Dashboard]]
> Design tokens: [[20_New_Design_System]] · Audio sync deferred: [[19_Future_Transcript_Audio_Sync]]

## What Was Built

Complete frontend UI overhaul from dark gray-800 theme to light parchment design
inspired by Google AI Studio reference app at `N:\projects\Google-Inspo`.

The redesign went through 3 iterations before landing on the final light theme,
built directly from reading `N:\projects\Google-Inspo\src\App.tsx` source code.

Final design: precision instrument / newspaper aesthetic.
High-contrast monochrome, sharp boxy borders, semantic colour for data only.

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| `@import must precede all other statements` | `@import "tailwindcss"` placed before Google Fonts `@import url(...)` | Moved Google Fonts import to top of `index.css` |
| `Unexpected token` parse error in CallDetail.tsx | Mismatched JSX braces from incremental edits | Rewrote file completely |
| Audio bar always hidden | HEAD request to MinIO blocked by CORS | Removed audio feature entirely |
| Login-on-every-reload | Zustand in-memory store cleared on page reload | Added `zustand/middleware persist` with `sessionStorage` |
| Agent tab completely empty | `page_size=200` exceeds API max of 100 | Rewrote to fetch 3 pages max |
| Recent Activity not clickable | No `onClick` handler, no `CallDetailPanel` in Overview | Added `selectedCallId` state + `CallDetailPanel` |
| Call History filter default wrong | Default `status='complete'` hid non-complete calls from ALL view | Changed default to `''` (ALL) |
| Score display inconsistent | Overview showed raw 0-10 scale while other pages showed ×10 percentage | Fixed Overview to multiply avgScore ×10 |

## Architecture Decisions

- `CallDetailPanel.tsx` — shared slide-in panel used by both `CallList.tsx` and `Overview.tsx`
- `motion/react` AnimatePresence for slide-in from right — matches Google AI Studio reference
- RadarChart for 5-metric performance visualization
- `fetchAllAgentCalls()` standalone function — fetches up to 3 pages (300 calls)
- **Score display rule (invariant):** backend stores 0–10, UI shows ×10 as percentage

## Design Tokens (Final)

| Token | Value |
|---|---|
| Background | `#E4E3E0` warm parchment |
| Cards | `bg-white border border-[#141414]` sharp edges |
| Active nav | `bg-[#141414] text-[#E4E3E0]` full-width |
| Body font | Inter |
| Data font | JetBrains Mono |
| Header font | Playfair Display italic |
| Score >80% | `#10b981` emerald |
| Score 60-80% | `#141414` black |
| Score <60% | `#ef4444` red |

## Invariants Confirmed

- Score display: `score * 10` as percentage everywhere in UI
- JWT in Zustand sessionStorage — not localStorage
- `CallDetailPanel` is the single component for call detail rendering
- Audio feature removed — no `<audio>` elements in codebase
