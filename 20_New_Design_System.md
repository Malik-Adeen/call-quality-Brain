---
tags: [frontend, design, redesign, google-ai-studio]
date: 2026-04-12
status: reference
---

# 20 — New Design System (Google AI Studio Inspired)

## Design Philosophy

Technical Dashboard / Information-Dense design language.
Feels like a professional precision instrument — mission control, not a generic corporate web app.
Human vs Machine typography tension — serif for names, monospace for data, sans-serif for body.

---

## Colour Palette

### Backgrounds
| Use | Hex | Tailwind |
| --- | --- | --- |
| Main canvas | `#131314` | `bg-[#131314]` |
| Sidebar | `#1E1E20` | `bg-[#1E1E20]` |
| Card | `#1E1E20` | `bg-[#1E1E20]` |
| Elevated card / modal | `#282A2C` | `bg-[#282A2C]` |

### Borders
| Use | Hex | Tailwind |
| --- | --- | --- |
| Default | `#444746` | `border-[#444746]` |
| Subtle / dividers | `#333537` | `border-[#333537]` |
| Active / focus | `#A8C7FA` | `border-[#A8C7FA]` |

### Text
| Use | Hex | Tailwind |
| --- | --- | --- |
| Primary | `#E3E3E3` | `text-[#E3E3E3]` |
| Secondary | `#C4C7C5` | `text-[#C4C7C5]` |
| Muted | `#8E918F` | `text-[#8E918F]` |
| Disabled | `#5F6368` | `text-[#5F6368]` |

### Accent (Google Blue)
| Use | Hex | Tailwind |
| --- | --- | --- |
| Primary | `#A8C7FA` | `text-[#A8C7FA]` / `bg-[#A8C7FA]` |
| Hover | `#D3E3FD` | `hover:bg-[#D3E3FD]` |
| Active subtle bg | `#004A77` | `bg-[#004A77]` |
| On-accent text | `#041E49` | `text-[#041E49]` |

### Status
| Use | Hex | Tailwind |
| --- | --- | --- |
| Success | `#81C995` | `text-[#81C995]` |
| Warning | `#FDE293` | `text-[#FDE293]` |
| Error | `#F28B82` | `text-[#F28B82]` |

---

## Typography

| Use | Classes |
| --- | --- |
| Page title | `text-2xl font-medium text-[#E3E3E3] tracking-tight` |
| Section header | `text-lg font-medium text-[#E3E3E3]` |
| Body | `text-sm font-normal text-[#C4C7C5] leading-relaxed` |
| Label | `text-xs font-medium text-[#8E918F] uppercase tracking-wider` |
| Table header | `text-xs font-medium text-[#8E918F] uppercase tracking-wider` |
| Timestamp | `text-xs font-mono text-[#8E918F]` |
| KPI number | `text-3xl font-mono font-bold text-[#E3E3E3]` |
| Agent name / call title | `font-serif italic text-[#E3E3E3]` (Playfair Display) |

---

## Sidebar

```
Container:    w-[280px] bg-[#1E1E20] border-r border-[#333537] h-screen flex flex-col
Active link:  flex items-center gap-3 px-4 py-2.5 mx-3 rounded-full bg-[#004A77] text-[#D3E3FD] text-sm font-medium
Default link: flex items-center gap-3 px-4 py-2.5 mx-3 rounded-full text-[#C4C7C5] hover:bg-[#282A2C] hover:text-[#E3E3E3] text-sm font-medium transition-colors
Brand area:   flex items-center h-16 px-7 text-lg font-medium text-[#E3E3E3] border-b border-[#333537] mb-4
```

---

## Card

```
Container:  bg-[#1E1E20] border border-[#444746] rounded-2xl p-6 shadow-none
Header:     flex items-center justify-between mb-4 pb-4 border-b border-[#333537]
Divider:    h-px w-full bg-[#333537] my-4
```

---

## Table

```
Header row:  border-b border-[#444746] bg-[#131314]
Header cell: px-4 py-3 text-xs font-medium text-[#8E918F] uppercase tracking-wider
Body row:    border-b border-[#333537] hover:bg-[#282A2C] transition-colors cursor-pointer
Body cell:   px-4 py-3 text-sm text-[#C4C7C5]
```

---

## Form Inputs + Buttons

```
Input:     w-full bg-[#131314] border border-[#444746] rounded-xl px-4 py-2.5 text-sm text-[#E3E3E3] placeholder-[#8E918F] focus:outline-none focus:border-[#A8C7FA] focus:ring-1 focus:ring-[#A8C7FA] transition-all
Primary:   inline-flex items-center justify-center px-6 py-2.5 rounded-full bg-[#A8C7FA] text-[#041E49] text-sm font-medium hover:bg-[#D3E3FD] transition-colors
Secondary: inline-flex items-center justify-center px-6 py-2.5 rounded-full border border-[#444746] bg-transparent text-[#A8C7FA] text-sm font-medium hover:bg-[#004A77]/30 transition-colors
```

---

## Badge / Chip

```
Base:       inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border
High score: bg-[#0F5223]/30 text-[#81C995] border-[#81C995]/30
Mid score:  bg-[#684B00]/30 text-[#FDE293] border-[#FDE293]/30
Low score:  bg-[#69211A]/30 text-[#F28B82] border-[#F28B82]/30
```

Score thresholds: High ≥ 7.5 · Mid 5.5–7.4 · Low < 5.5

---

## Recharts Config

```jsx
<Tooltip
  contentStyle={{ backgroundColor: '#282A2C', borderColor: '#444746', borderRadius: '12px', color: '#E3E3E3', padding: '12px' }}
  itemStyle={{ color: '#C4C7C5', fontSize: '14px' }}
/>
<CartesianGrid strokeDasharray="3 3" stroke="#333537" />
<XAxis tick={{ fill: '#8E918F', fontSize: 12 }} />
<YAxis tick={{ fill: '#8E918F', fontSize: 12 }} />
```

Line/area colours:
- Primary: `#A8C7FA`
- Success: `#81C995`
- Warning: `#FDE293`
- Error: `#F28B82`

---

## Fonts to Add

Add to `index.html` `<head>`:
```html
<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:ital@1&family=JetBrains+Mono:wght@400;500;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
```

Add to `index.css`:
```css
body { font-family: 'Inter', sans-serif; }
.font-mono { font-family: 'JetBrains Mono', monospace; }
.font-serif { font-family: 'Playfair Display', serif; }
```

---

## Key Visual Differences from Previous Design

| Old (gray-800 dark) | New (AI Studio inspired) |
| --- | --- |
| `bg-gray-800` cards | `bg-[#1E1E20]` cards |
| `border-gray-700` | `border-[#444746]` |
| `blue-500` accent | `#A8C7FA` soft blue accent |
| `rounded-lg` cards | `rounded-2xl` cards |
| Standard sans-serif | Three-font system (Inter + JetBrains Mono + Playfair Display) |
| Rounded sidebar links | Rounded-full pill sidebar links |
| Score: emerald/amber/rose | Score: `#81C995` / `#FDE293` / `#F28B82` |
