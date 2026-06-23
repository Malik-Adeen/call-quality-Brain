---
tags: [changelog, ui, frontend]
date: 2026-04-19
status: verified
---

# UI Polish Changelog — Overview, Agents, Call History, Call Detail

Verified against live code by filesystem audit on 2026-04-19.

---

## CallList.tsx

- Selected-row persistence: `isSelected = selectedId === call.id`; active row gets `bg-[#f5f5f4] border-l-[#141414]`, unselected gets `border-l-transparent hover:bg-[#fafaf9]`
- Sentiment badge contrast upgrade: Positive `border-[#065f46] bg-[#dcfce7] text-[#065f46]`, Negative `border-[#991b1b] bg-[#fee2e2] text-[#991b1b]`, Neutral `border-[#4b5563] bg-[#f3f4f6] text-[#374151]`
- Badge shape: bordered mono uppercase, no rounded pill

## CallDetailPanel.tsx

- `formatDateTime(iso)` helper added — explicit locale datetime display
- Metadata row: Call time / Duration / Evaluated at (NOTE: Call time and Evaluated at both map to `call.created_at` — same value, known limitation, no separate pipeline completion timestamp available)
- `parseTranscriptLine(line)` helper: AGENT right-aligned, CUSTOMER left-aligned, TRANSCRIPT neutral
- Transcript: `whitespace-pre-wrap break-words` applied to message body
- Radar interpretability: compact 2-column metric value grid rendered below chart
- Unused imports (BarChart, Bar, Cell) removed
- Sentiment tooltip formatter: `unknown`-safe typed coercion applied

## Overview.tsx

- Full sea-level command-center layout: `lg:grid-cols-12` responsive grid
- External transform module: `frontend/src/utils/dashboardTransforms.ts` (groupByDay, coachingRiskByAgent, issueSpike, dayHourMatrix)
- 6 panels implemented:
  1. Volume & Quality — ComposedChart (bar volume + line score)
  2. Requires Attention — risk-ranked agent roster (minCalls=5 filter active)
  3. Issue Spike Monitor — grouped BarChart current 7d vs previous 7d
  4. Day×Hour Heatmap — ScatterChart square cells, Mon-first, 00-23
  5. Sentiment Trend — dual LineChart avgStart vs avgEnd
  6. Outcomes Mix — stacked BarChart resolved/unresolved/low-score-unresolved
- KPI trend chips on Avg Score and Resolution Rate (weighted period comparison)
- Last updated timestamp in header
- Heatmap mini legend (good/neutral/bad color key)
- Custom tooltip components with sample size (n) field
- `formatCount` and `formatPercent` helpers with NaN guards
- `tabular-nums` applied to KPI values

## Agents.tsx

- `activeAgentId` explicit selected-agent state
- Default selection: lowest-score agent (sort ascending, select index 0)
- Selection fallback: second useEffect guards against stale activeAgentId after refresh
- "Viewing: <name>" context label above lower panels
- Sorted worst-first (ascending avgScore)
- Rank badges (#1, #2, ...)
- Score unified to percentages: Y-axis 0-100%, all displays via `toScorePercent()`
- Semantic color thresholds: >80 #10b981, 60-80 #141414, <60 #ef4444
- Strengths: metric > 0.7; Areas: metric < 0.7; exactly 0.7 excluded from both (strict operators)
- Δ7d chip: computeDelta7d() compares current 7d vs previous 7d; flat epsilon = 0.1pp
- Confidence label: <20 calls = 'low confidence', ≥20 = 'stable sample'
- Truncation hardening: name truncated, confidence label whitespace-nowrap
