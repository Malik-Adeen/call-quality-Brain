---
tags: [frontend, design, tailwind, recharts]
date: 2026-04-11
status: reference
---

## Design System — AI Call Quality Dashboard

Generated via Gemini. Use these tokens for every React component. No deviations.

---

## Accent Colour

- Primary: `blue-500` — `#3b82f6`
- Hover: `hover:bg-blue-600`
- Focus ring: `focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 focus:ring-offset-gray-900`

---

## Typography

| Use | Classes |
| --- | --- |
| Page title | `text-2xl font-semibold text-gray-100 tracking-tight` |
| Card/section header | `text-lg font-medium text-gray-200` |
| KPI stat number | `text-3xl font-bold text-white` |
| Body text | `text-sm text-gray-300` |
| Table headers / labels | `text-xs font-medium text-gray-400 uppercase tracking-wider` |
| Helper / timestamp | `text-xs text-gray-500` |

---

## Card Component

```
bg-gray-800 rounded-lg p-6 border border-gray-700 shadow-sm
```

Compact card (list items):
```
bg-gray-800 rounded-lg p-4 border border-gray-700
```

Split panel divider (Call Detail):
```
divide-x divide-gray-700
```

---

## Sidebar Layout

```
Container:     w-64 h-screen fixed left-0 top-0 bg-gray-900 border-r border-gray-800 flex flex-col px-3 py-4 space-y-1
Active link:   flex items-center px-3 py-2 text-sm font-medium rounded-md bg-gray-800 text-blue-500
Default link:  flex items-center px-3 py-2 text-sm font-medium rounded-md text-gray-400 hover:bg-gray-800 hover:text-gray-200 transition-colors
Main content:  ml-64 min-h-screen bg-gray-900 p-8
```

---

## Score Colour System

| Score | Text | Badge |
| --- | --- | --- |
| ≥ 7.5 (good) | `text-emerald-400` | `bg-emerald-400/10 text-emerald-400 border border-emerald-400/20 px-2 py-1 rounded-full text-xs font-medium` |
| 5.5–7.4 (average) | `text-amber-400` | `bg-amber-400/10 text-amber-400 border border-amber-400/20 px-2 py-1 rounded-full text-xs font-medium` |
| < 5.5 (poor) | `text-rose-400` | `bg-rose-400/10 text-rose-400 border border-rose-400/20 px-2 py-1 rounded-full text-xs font-medium` |

---

## Recharts Colour Palette

| Use | Hex | Tailwind |
| --- | --- | --- |
| Primary line / bar | `#3b82f6` | blue-500 |
| Benchmark / secondary line (dashed) | `#9ca3af` | gray-400 |
| Score bar 1 — politeness | `#3b82f6` | blue-500 |
| Score bar 2 — sentiment | `#0ea5e9` | sky-500 |
| Score bar 3 — resolution | `#06b6d4` | cyan-500 |
| Score bar 4 — talk balance | `#14b8a6` | teal-500 |
| Score bar 5 — clarity | `#10b981` | emerald-500 |
| Axis / grid lines | `#374151` | gray-700 |

### Tooltip config (copy-paste into every Recharts component)
```jsx
<Tooltip
  contentStyle={{ backgroundColor: '#1f2937', borderColor: '#374151', color: '#f3f4f6', borderRadius: '0.5rem' }}
  itemStyle={{ color: '#e5e7eb' }}
/>
```

### CartesianGrid config
```jsx
<CartesianGrid strokeDasharray="3 3" stroke="#374151" />
```

---

## Global Background

```
bg-gray-900
```
