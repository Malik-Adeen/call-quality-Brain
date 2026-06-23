---
tags: [frontend, design, redesign]
date: 2026-05-03
status: active — use this for the UI redesign
source: Notion official DESIGN.md (design.google format)
---

# 20 — New Design System (Notion Official)

> This file replaces all previous design system docs.
> Source: Notion's official DESIGN.md extracted from their design system.
> Use EVERY token from this file in the UI redesign — do not deviate.

---

## Colour Palette

### Core Backgrounds
| Token | Hex | Use |
|---|---|---|
| `canvas` | `#ffffff` | Page background, card background |
| `surface` | `#f6f5f4` | Secondary surface, input bg, sidebar |
| `surface-soft` | `#fafaf9` | Hover states, subtle fills |
| `brand-navy` | `#0a1530` | Hero bands, dark sections |
| `brand-navy-mid` | `#1a2a52` | Hero band mid tone |

### Borders
| Token | Hex | Use |
|---|---|---|
| `hairline` | `#e5e3df` | Default borders |
| `hairline-soft` | `#ede9e4` | Dividers, row separators |
| `hairline-strong` | `#c8c4be` | Input borders, emphasis |

### Text
| Token | Hex | Use |
|---|---|---|
| `ink` | `#1a1a1a` | Primary body text |
| `charcoal` | `#37352f` | Secondary headings |
| `slate` | `#5d5b54` | Secondary text |
| `steel` | `#787671` | Muted labels, placeholders |
| `stone` | `#a4a097` | Disabled, hints |
| `muted` | `#bbb8b1` | Placeholder, disabled text |
| `on-dark` | `#ffffff` | Text on dark/navy bg |

### Accent (Primary)
| Token | Hex | Use |
|---|---|---|
| `primary` | `#5645d4` | Primary CTA, focus rings, active states |
| `primary-pressed` | `#4534b3` | Button pressed state |
| `primary-deep` | `#3a2a99` | Deep hover |

### Semantic
| Token | Hex | Use |
|---|---|---|
| `semantic-success` | `#1aae39` | Resolved, positive sentiment |
| `semantic-warning` | `#dd5b00` | Needs review, warnings |
| `semantic-error` | `#e03131` | Failed, negative, low scores |

### Pastel Card Tints (use for stat cards, feature sections)
| Token | Hex |
|---|---|
| `card-tint-peach` | `#ffe8d4` |
| `card-tint-rose` | `#fde0ec` |
| `card-tint-mint` | `#d9f3e1` |
| `card-tint-lavender` | `#e6e0f5` |
| `card-tint-sky` | `#dcecfa` |
| `card-tint-yellow` | `#fef7d6` |
| `card-tint-cream` | `#f8f5e8` |
| `card-tint-gray` | `#f0eeec` |

---

## Typography

Font: **Notion Sans** (load via Google Fonts as Inter — nearest match. Notion Sans is Inter-based.)

```html
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
```

| Token | Size | Weight | Use |
|---|---|---|---|
| `heading-4` | 22px | 600 | Page section headers |
| `heading-5` | 18px | 600 | Card headers, panel titles |
| `subtitle` | 18px | 400 | Subheadings, descriptions |
| `body-md` | 16px | 400 | Body text |
| `body-md-medium` | 16px | 500 | Emphasised body |
| `body-sm` | 14px | 400 | Table cells, secondary content |
| `body-sm-medium` | 14px | 500 | Labels, nav items |
| `caption` | 13px | 400 | Timestamps, captions |
| `caption-bold` | 13px | 600 | Badge text |
| `micro` | 12px | 500 | Micro labels |
| `micro-uppercase` | 11px | 600 | Table headers, uppercase labels (+ 1px letter-spacing) |
| `button-md` | 14px | 500 | All buttons |

**Drop:** Playfair Display, JetBrains Mono — not in Notion's system.
**Exception:** Keep JetBrains Mono only for transcript text and data values (scores, timestamps).

---

## Spacing Scale

| Token | Value |
|---|---|
| `xxs` | 4px |
| `xs` | 8px |
| `sm` | 12px |
| `md` | 16px |
| `lg` | 20px |
| `xl` | 24px |
| `xxl` | 32px |
| `xxxl` | 40px |
| `section-sm` | 48px |
| `section` | 64px |

---

## Border Radius

| Token | Value | Use |
|---|---|---|
| `xs` | 4px | — |
| `sm` | 6px | Small elements |
| `md` | 8px | **Buttons** (rectangles, NOT pills) |
| `lg` | 12px | **Cards** |
| `xl` | 16px | Large panels |
| `xxl` | 20px | Modal dialogs |
| `full` | 9999px | Pill badges, pill tabs only |

> **Critical:** Buttons use `rounded-md` (8px). Cards use `rounded-lg` (12px). Never use pill-shaped buttons.

---

## Components

### Buttons

**Primary (purple)**
```
bg: #5645d4  text: #fff  font: 14px/500  rounded: 8px  padding: 10px 18px  min-height: 44px
hover: bg #4534b3
disabled: bg #e5e3df  text: #bbb8b1
```

**Dark (black)**
```
bg: #000000  text: #fff  font: 14px/500  rounded: 8px  padding: 10px 18px  min-height: 44px
```

**Secondary (outlined)**
```
bg: transparent  text: #1a1a1a  border: 1px solid #c8c4be  rounded: 8px  padding: 10px 18px  min-height: 44px
hover: bg #f6f5f4
```

**Ghost (quiet)**
```
bg: transparent  text: #1a1a1a  padding: 8px 12px  rounded: 6px
hover: bg #f6f5f4
```

**Destructive**
```
bg: #fff2f2  text: #e03131  border: 1px solid #fca5a5  rounded: 8px  padding: 10px 18px
hover: bg #fee2e2
```

### Inputs

**Text input**
```
bg: #ffffff  text: #1a1a1a  border: 1px solid #c8c4be  rounded: 8px
padding: 12px 16px  height: 44px  placeholder: #787671
focus: border 2px solid #5645d4  ring: none
```

**Select / Dropdown**
```
Same as text input + chevron icon right
```

### Cards

**Standard card**
```
bg: #ffffff  border: 1px solid #e5e3df  rounded: 12px  padding: 24px
```

**Surface card (secondary)**
```
bg: #f6f5f4  border: 1px solid #e5e3df  rounded: 12px  padding: 24px
```

**Featured card (primary accent)**
```
bg: #ffffff  border: 2px solid #5645d4  rounded: 12px  padding: 24px
```

**Pastel stat card** (for KPIs on dashboard)
```
Use card-tint-* colors as bg. text: #37352f  rounded: 12px  padding: 24px
```

### Sidebar

```
bg: #f6f5f4  width: 240px  border-right: 1px solid #e5e3df  height: 100vh

Brand area:
  height: 56px  padding: 0 16px  border-bottom: 1px solid #e5e3df
  logo: 28px box  bg: #000  color: #fff
  text: 14px/600 #1a1a1a

Nav link (inactive):
  padding: 6px 12px  rounded: 6px  margin: 1px 8px
  text: 14px/500 #5d5b54
  hover: bg #ede9e4  text: #1a1a1a

Nav link (active):
  bg: #ede9e4  text: #1a1a1a  font: 14px/600
  left border: 2px solid #5645d4

Tenant pill:
  bg: #ede9e4  rounded: 6px  padding: 6px 10px
  text: 11px/600 uppercase #5d5b54

Footer area:
  border-top: 1px solid #e5e3df  padding: 12px 8px
```

### Navigation Header (app header)

```
bg: #ffffff  height: 56px  border-bottom: 1px solid #e5e3df  padding: 0 24px
sticky top-0 z-10

Left: page title — 16px/600 #1a1a1a
Right: dark/light toggle icon button + user avatar (28px)
```

### Badges

```
Score high (≥75%):  bg #d9f3e1  text #1aae39  rounded-full  padding 2px 10px  font 11px/600
Score mid (55-74%): bg #fef7d6  text #dd5b00  rounded-full  padding 2px 10px  font 11px/600
Score low (<55%):   bg #fff2f2  text #e03131  rounded-full  padding 2px 10px  font 11px/600

Needs Review:       bg #ffe8d4  text #dd5b00  rounded-full  padding 2px 10px  font 11px/600
Status complete:    bg #d9f3e1  text #1aae39  rounded-sm   padding 2px 8px   font 11px/600
Status processing:  bg #dcecfa  text #0075de  rounded-sm   padding 2px 8px   font 11px/600
Status failed:      bg #fff2f2  text #e03131  rounded-sm   padding 2px 8px   font 11px/600
```

### Tables

```
Header row:   bg #f6f5f4  border-bottom: 1px solid #e5e3df
Header cell:  padding 10px 16px  font 11px/600 uppercase tracking-wide  color #787671
Body row:     border-bottom: 1px solid #ede9e4  hover: bg #fafaf9  cursor pointer
Body cell:    padding 12px 16px  font 14px/400  color #37352f
```

### Recharts Config (updated)

```jsx
<Tooltip
  contentStyle={{
    backgroundColor: '#ffffff',
    borderColor: '#e5e3df',
    borderRadius: '12px',
    color: '#1a1a1a',
    fontSize: 13,
    padding: '12px 16px',
  }}
  itemStyle={{ color: '#5d5b54', fontSize: 13 }}
/>
<CartesianGrid strokeDasharray="3 3" stroke="#ede9e4" vertical={false} />
<XAxis tick={{ fill: '#787671', fontSize: 12 }} axisLine={false} tickLine={false} />
<YAxis tick={{ fill: '#787671', fontSize: 12 }} axisLine={false} tickLine={false} />
```

Line/area colours:
- Primary line: `#5645d4` (purple)
- Success/positive: `#1aae39`
- Warning: `#dd5b00`
- Error/negative: `#e03131`
- Neutral: `#787671`

---

## Dark Mode

Notion's design system does not specify full dark mode token values beyond the hero band.
For dark mode, use Google AI Studio tokens from `20_New_Design_System_Archive.md` (canvas `#131314`, cards `#1E1E20`, accent `#A8C7FA`).

**Decision:** Implement light mode first (Notion tokens). Add dark mode toggle after.

---

## Do's and Don'ts

**Do:**
- Use `#5645d4` purple as the ONLY CTA colour
- `rounded-md` (8px) on ALL buttons — rectangular, not pill
- `rounded-lg` (12px) on ALL cards
- Pastel card tints for KPI stat cards on dashboard
- Inter 400/500/600 only — no 700, no 300
- 44px min-height on all interactive elements

**Don't:**
- Pill-shaped buttons (Notion uses rectangles)
- Playfair Display serif (removed from system)
- Heavy box shadows on cards (Notion is flat)
- Mix purple (`#5645d4`) with blue (`#0075de`) — they have separate roles
- `text-purple` on body text
