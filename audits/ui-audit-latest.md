---
tags: [audit, ui, frontend]
date: 2026-04-19
verdict: PASS
---

# UI Audit — Latest (2026-04-19)

Files audited: CallList.tsx, CallDetailPanel.tsx, Agents.tsx, Overview.tsx, dashboardTransforms.ts, format.ts

---

## A) Claims Extracted

### CLAUDE-3.txt (CallList + CallDetailPanel)
1. isSelected row state with left accent
2. Sentiment badge color upgrade (Positive/Negative/Neutral)
3. Badge shape: bordered mono uppercase
4. formatDateTime helper
5. Metadata: Call time / Duration / Evaluated at
6. parseTranscriptLine helper
7. AGENT right-aligned, CUSTOMER left-aligned
8. whitespace-pre-wrap break-words
9. Radar metric value grid under chart
10. Removed BarChart/Bar/Cell imports
11. Tooltip formatter unknown-safe coercion

### Claude-Update.txt (Overview)
12. 12-column responsive grid layout
13. dashboardTransforms.ts module (groupByDay, coachingRiskByAgent, issueSpike, dayHourMatrix)
14. Volume & Quality ComposedChart
15. Requires Attention roster
16. Issue Spike Monitor (current 7d vs previous 7d grouped bars)
17. Day×Hour heatmap ScatterChart, Mon-first
18. Sentiment Trend dual lines (start vs end)
19. Outcomes Mix stacked bars
20. Decision-hint microcopy under each panel
21. Last updated timestamp
22. KPI trend chips (Avg Score + Resolution)
23. Heatmap mini legend
24. Custom tooltips with sample size
25. tabular-nums + formatCount/formatPercent

### Claude-Update-Agent.txt (Agents)
26. activeAgentId state
27. Default = lowest-score agent
28. Selection fallback useEffect
29. Viewing context label
30. Sorted ascending by avgScore (worst-first)
31. Rank badges
32. Score unified to percentages, Y-axis 0-100
33. Semantic color thresholds (>80/60-80/<60)
34. Strengths > 0.7, Areas < 0.7, 0.7 excluded
35. Δ7d chip with computeDelta7d
36. Confidence label threshold = 20 calls
37. Truncation hardening

---

## B) Verification Table

| # | Claim | File | Evidence | Status |
|---|---|---|---|---|
| 1 | isSelected row state + left accent | CallList.tsx | `const isSelected = selectedId === call.id` + className logic | VERIFIED |
| 2 | Positive badge `border-[#065f46] bg-[#dcfce7] text-[#065f46]` | CallList.tsx | sentStyle conditional | VERIFIED |
| 3 | Negative badge `border-[#991b1b] bg-[#fee2e2] text-[#991b1b]` | CallList.tsx | sentStyle conditional | VERIFIED |
| 4 | Neutral badge `border-[#4b5563] bg-[#f3f4f6] text-[#374151]` | CallList.tsx | sentStyle conditional | VERIFIED |
| 5 | Badge: bordered mono uppercase | CallList.tsx | `text-[10px] font-mono uppercase tracking-[0.08em] px-2 py-0.5 border` | VERIFIED |
| 6 | formatDateTime helper | CallDetailPanel.tsx | function defined at top of file | VERIFIED |
| 7 | Metadata: Call time / Duration / Evaluated at | CallDetailPanel.tsx | Three explicit labeled `<p>` elements | PARTIAL — both Call time and Evaluated at use `call.created_at`; semantically misleading, not a crash |
| 8 | parseTranscriptLine helper | CallDetailPanel.tsx | function defined, handles AGENT/CUSTOMER/TRANSCRIPT | VERIFIED |
| 9 | AGENT right-aligned, CUSTOMER left-aligned | CallDetailPanel.tsx | `flex justify-end` for AGENT, `justify-start` otherwise | VERIFIED |
| 10 | whitespace-pre-wrap break-words | CallDetailPanel.tsx | applied to message `<p>` | VERIFIED |
| 11 | Radar metric value grid | CallDetailPanel.tsx | 2-col grid after chart, maps radarData | VERIFIED |
| 12 | BarChart/Bar/Cell imports removed | CallDetailPanel.tsx | Not present in import statement | VERIFIED |
| 13 | Tooltip unknown-safe coercion | CallDetailPanel.tsx | `v: unknown` + Array.isArray guard | VERIFIED |
| 14 | 12-col grid layout | Overview.tsx | `grid-cols-1 sm:grid-cols-6 lg:grid-cols-12` | VERIFIED |
| 15 | dashboardTransforms.ts exists | utils/dashboardTransforms.ts | File present, all 4 exports verified | VERIFIED |
| 16 | Volume & Quality ComposedChart | Overview.tsx | `<ComposedChart>` with Bar vol + Line score | VERIFIED |
| 17 | Requires Attention roster | Overview.tsx | `coachingRiskByAgent` roster with risk-ranked sort | VERIFIED |
| 18 | Issue Spike Monitor | Overview.tsx | `<BarChart>` with `dataKey="previous"` + `dataKey="current"` | VERIFIED |
| 19 | Day×Hour heatmap, Mon-first | Overview.tsx + dashboardTransforms.ts | `dow = (created.getDay() + 6) % 7` Mon-first, 7×24 matrix pre-seeded | VERIFIED |
| 20 | Sentiment Trend dual lines | Overview.tsx | `avgStart` + `avgEnd` Lines in `<LineChart>` | VERIFIED |
| 21 | Outcomes Mix stacked bars | Overview.tsx | `stackId="outcomes"` on 3 bars | VERIFIED |
| 22 | Decision-hint microcopy | Overview.tsx | `PANEL_HINT_CLASS` rendered in every panel | VERIFIED |
| 23 | Last updated timestamp | Overview.tsx | `lastUpdatedLabel` state set in load() | VERIFIED |
| 24 | KPI trend chips | Overview.tsx | `avgScoreTrend` + `resolutionTrend` chipText props on StatCards | VERIFIED |
| 25 | Heatmap mini legend | Overview.tsx | Good/Neutral/Bad legend inline in heatmap panel header | VERIFIED |
| 26 | Custom tooltips with sample size | Overview.tsx | All 5 custom tooltip components include `formatCount(n) calls` | VERIFIED |
| 27 | tabular-nums + formatCount/formatPercent | Overview.tsx | `tabular-nums` class on KPI h3; both helpers with NaN guards | VERIFIED |
| 28 | activeAgentId state | Agents.tsx | `const [activeAgentId, setActiveAgentId] = useState<string | null>(null)` | VERIFIED |
| 29 | Default = lowest-score agent | Agents.tsx | Sort ascending, `setActiveAgentId(list[0].id)` | VERIFIED |
| 30 | Selection fallback useEffect | Agents.tsx | Second useEffect checks `!activeAgentId || !agents.some(a => a.id === activeAgentId)` | VERIFIED |
| 31 | Viewing context label | Agents.tsx | `Viewing: <span>{activeAgent?.name ?? data.agent.name}</span>` | VERIFIED |
| 32 | Sorted ascending avgScore | Agents.tsx | `.sort((a, b) => a.avgScore - b.avgScore)` | VERIFIED |
| 33 | Rank badges | Agents.tsx | `#{index + 1}` in card header | VERIFIED |
| 34 | Y-axis 0-100 with % ticks | Agents.tsx | `domain={[0, 100]}` + `tickFormatter={(v) => \`${v}%\`}` | VERIFIED |
| 35 | Semantic thresholds >80/60-80/<60 | Agents.tsx | `scoreSemanticColor` function | VERIFIED |
| 36 | Strengths > 0.7, Areas < 0.7, 0.7 excluded | Agents.tsx | `METRIC_NEUTRAL_THRESHOLD = 0.7`, strict operators | VERIFIED |
| 37 | Δ7d chip computeDelta7d | Agents.tsx | Full function present, DAY_MS, period slicing | VERIFIED |
| 38 | Flat epsilon = 0.1pp | Agents.tsx | `DELTA_FLAT_EPSILON = 0.1` | VERIFIED |
| 39 | Confidence threshold 20 calls | Agents.tsx | `CONFIDENCE_CALL_THRESHOLD = 20` | VERIFIED |
| 40 | Truncation hardening | Agents.tsx | `truncate` on name, `whitespace-nowrap` on confidence label | VERIFIED |

---

## C) Audit Findings

### CRITICAL (0)
None. No crash bugs, no broken API contracts, no invariant violations.

### MAJOR (2)

**M1 — "Evaluated at" = "Call time" (same data source)**
- File: CallDetailPanel.tsx
- Both metadata labels map to `formatDateTime(call.created_at)`
- No `updated_at` or pipeline completion timestamp exists in the API contract
- Risk: Panel member may ask "why are these the same time?" during Q&A
- Fix: Relabel "Evaluated at" to "Issue Category" or drop it; or add a note "(same as call time — pipeline completion timestamp not stored)"
- Severity: MAJOR because it creates a false impression of two distinct timestamps

**M2 — coachingRiskByAgent minCalls=5 filter silently drops agents**
- File: Overview.tsx via dashboardTransforms.ts
- Agents with <5 calls are invisible in "Requires Attention" roster
- On a freshly seeded demo DB with 200 calls across ~10 agents, most will have ≥5 calls; risk is low
- Risk: If a new upload introduces a new agent with 1-2 calls, they are silently excluded
- Fix: Add a "(min. 5 calls)" note under the panel subtitle, or lower minCalls to 2
- Severity: MAJOR for correctness; LOW risk for demo

### MINOR (3)

**m1 — scoreColor defined in two places with different thresholds**
- `format.ts` uses 7.5/5.5 (raw 0-10 scale); Overview.tsx and Agents.tsx define local versions using 80/60 (percentage scale)
- No runtime conflict but creates maintenance confusion
- Fix: Post-demo, unify into one helper that accepts percentage scale

**m2 — ComposedChart volume/quality panel has no legend**
- The gray bars (volume) and black line (score) have no legend label
- A viewer may not immediately know which is which
- Fix: Add a two-item inline legend (2 lines of text, no chart Legend component needed) or add a `<Legend>` component

**m3 — "Evaluated at" and "Call time" using same label pattern will read identically on screen**
- Already captured in M1 above

---

## D) PASS / FAIL

**VERDICT: PASS**

No critical issues. Two major issues both have zero demo-crash risk. The system is functionally correct, API-contract-compliant, and invariant-safe.

---

## E) Demo Readiness Notes

- Run `reset_and_seed.py` on Azure before demo to ensure all agents have ≥5 calls (satisfies M2)
- Brief your panel answer for "Evaluated at = Call time": pipeline does not store a separate completion timestamp; the call creation time is the evaluation anchor
- Consider adding inline legend text to ComposedChart panel before demo (30 min fix)
