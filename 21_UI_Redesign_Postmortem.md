---
tags: [phase-3, ui, redesign, frontend, design-system]
date: 2026-04-14
status: complete
---

# 21 — UI Redesign Postmortem

## What Was Built

Complete frontend UI overhaul from dark gray-800 theme to a light parchment design inspired by Google AI Studio's reference app at `N:\projects\Google-Inspo`.

The redesign went through 3 iterations:
1. Dark Google AI Studio theme (`#131314` / `#1E1E20`) — built from Gemini's design system response
2. Light parchment theme attempt — partially incorrect from Gemini audit feedback on old design
3. Final light theme — built directly from reading `N:\projects\Google-Inspo\src\App.tsx` source code

Final design is a precision instrument / newspaper aesthetic. High-contrast monochrome, sharp boxy borders, semantic colour for data only.

## Bugs Encountered & Resolutions

| Bug | Root Cause | Fix |
|---|---|---|
| `@import must precede all other statements` PostCSS error | `@import "tailwindcss"` placed before Google Fonts `@import url(...)` | Moved Google Fonts import to top of `index.css` before `@import "tailwindcss"` |
| `Unexpected token` parse error in CallDetail.tsx | Mismatched JSX braces from incremental str_replace edits | Rewrote file completely from scratch |
| Audio bar always hidden | HEAD request to MinIO blocked by CORS | Replaced HEAD check with `audioAvailable=true` default + `onError` hide — then removed audio feature entirely |
| Audio file `404 NoSuchKey` | `minio_audio_path` in DB already contains `audio-uploads/` prefix but URL builder added it again | Added prefix strip in `generate_presigned_url` |
| Login-on-every-reload | Zustand in-memory store cleared on page reload | Added `zustand/middleware persist` with `sessionStorage` — survives reload, clears on tab close |
| Agent tab completely empty | `page_size=200` exceeds API max of 100, TypeScript generic type error in `Map` annotation | Rewrote to `fetchAllAgentCalls()` fetching 3 pages max, simplified type to `Map<string, CallSummary[]>` |
| Recent Activity not clickable | No `onClick` handler, no `CallDetailPanel` in Overview | Added `selectedCallId` state and rendered `CallDetailPanel` in Overview |
| Call History filter default wrong | Default `status='complete'` hid non-complete calls from ALL view | Changed default to `''` (ALL) |
| Search input decorative only | Header search had no handler, no connection to API or state | Removed from header, added inline search to CallList with client-side filter |
| Score display inconsistent | Overview showed `6.2%` (0-10 scale, not percentage) while other pages showed `69%` (×10) | Fixed Overview to multiply avgScore ×10 — invariant: backend is 0-10, UI shows ×10 as percentage |

## Architecture Decisions

- **Slide-in panel vs page navigation**: Call Detail now uses `motion/react` AnimatePresence slide-in from right, matching Google AI Studio reference exactly. `CallDetail.tsx` page is a thin wrapper that renders `CallDetailPanel`.
- **`CallDetailPanel.tsx`** is a shared component used by both `CallList.tsx` and `Overview.tsx` — single source of truth for call detail rendering.
- **RadarChart** used for performance metrics (5 axes) instead of BarChart — matches reference exactly.
- **`fetchAllAgentCalls()`** is a standalone async function outside the component that fetches up to 3 pages (300 calls) to ensure all agents are represented.
- **Score display rule**: Backend stores `0–10`. UI multiplies ×10 to show as percentage. This is an invariant applied everywhere.
- **Audio feature removed entirely** — CORS + ephemeral MinIO volumes make it unreliable. Feature spec deferred to [[19_Future_Transcript_Audio_Sync]].

## Design Tokens (Final)

| Token | Value |
|---|---|
| Background | `#E4E3E0` |
| Cards | `bg-white border border-[#141414]` |
| Active nav | `bg-[#141414] text-[#E4E3E0]` full-width |
| Body font | Inter |
| Data font | JetBrains Mono |
| Header font | Playfair Display italic |
| Score >80% | `#10b981` emerald |
| Score 60-80% | `#141414` black |
| Score <60% | `#ef4444` red |

## Dependencies Added

- `motion` (motion/react) — slide-in panel animations

## Invariants Confirmed

- Score display: `score * 10` as percentage everywhere in UI
- JWT in Zustand sessionStorage — not localStorage, not in-memory-only
- `CallDetailPanel` is the single component for call detail rendering
- Audio feature deferred — no `<audio>` elements in codebase

## Next Phase Entry Conditions

- All 6 pages render without console errors
- Clicking Recent Activity row opens slide-in panel
- Search in Call History filters results in real-time
- All 5 agents visible in Agents tab
- Score percentages consistent across Overview, CallList, Agents, and CallDetailPanel
