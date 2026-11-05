---
name: tailwind-v4
description: Production conventions, UI/UX design craftsmanship, and configuration standards for Tailwind CSS v4. Use when setting up, styling, or refactoring CSS with Tailwind v4, CSS-first @theme directives, OKLCH color palettes, 8px spatial grids, bespoke aesthetic archetypes, and WCAG AA contrast compliance.
---

# Tailwind CSS v4 & UI/UX Design Craftsmanship Guide

Runbook for styling modern web applications using Tailwind CSS v4, CSS-first `@theme` design tokens, OKLCH color spaces, 8px spatial grids, and bespoke craftsmanship that rejects generic AI aesthetics.

---

## 1. Craftsmanship Principles & Anti-AI Aesthetics

1. **Reject AI Clichés:** Never use generic dark-slate backgrounds paired with neon-purple or cyan gradients. Design intentional color palettes tailored to the specific application domain.
2. **Zero Emojis in UI:** Never use emojis in UI components, buttons, or headers. Use clean SVG vector icons (Lucide, Heroicons, Radix Icons).
3. **Intentional Typography:** Pair a distinctive display header (e.g. *Outfit*, *Space Grotesk*, *Newsreader*) with a clean, highly legible body sans (*Inter*, *Plus Jakarta Sans*).
4. **8px Spatial Grid:** All margins, paddings, and gaps must follow strict 8px increments (`4px` micro, `8px` button gap, `12px` compact padding, `16px` standard card, `24px` section, `32px` container gutters).
5. **Interactive Micro-Interactions:** Every interactive element must define Default, Hover (150ms ease), Active (`active:scale-[0.98]`), and high-contrast `focus-visible` rings.

---

## 2. Tailwind v4 Core Architecture: CSS-First

Tailwind v4 removes `tailwind.config.js` completely. All configuration lives directly in the root CSS entrypoint (`src/index.css`) using `@theme` and `@utility`.

```css
@import "tailwindcss";

@theme {
  /* Brand Typography */
  --font-sans: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  --font-display: "Outfit", "Inter", sans-serif;
  --font-mono: "JetBrains Mono", "Fira Code", monospace;

  /* Curated OKLCH Color Palette (Perceptually Uniform) */
  --color-brand-50: oklch(0.98 0.01 240);
  --color-brand-500: oklch(0.60 0.18 250);
  --color-brand-600: oklch(0.52 0.20 250);

  /* Surface & Elevation Tokens (8px Grid & WCAG AA) */
  --color-surface-base: oklch(0.14 0.01 260);
  --color-surface-card: oklch(0.18 0.02 260);
  --color-surface-border: oklch(0.26 0.02 260);
  --color-text-primary: oklch(0.96 0.01 260);
  --color-text-muted: oklch(0.70 0.02 260);

  /* 8px Spatial Grid Spacing */
  --spacing-grid-1: 4px;
  --spacing-grid-2: 8px;
  --spacing-grid-3: 12px;
  --spacing-grid-4: 16px;
  --spacing-grid-6: 24px;
  --spacing-grid-8: 32px;
}

/* Custom Bespoke Utilities */
@utility glass-panel {
  background: oklch(0.18 0.02 260 / 0.7);
  backdrop-filter: blur(12px);
  border: 1px solid oklch(0.28 0.02 260 / 0.4);
}

@utility elevation-card {
  box-shadow: 0 4px 20px -2px oklch(0 0 0 / 0.25);
  border: 1px solid oklch(1 0 0 / 0.08);
}
```

---

## 3. Curated Aesthetic Archetypes

- **Technical Swiss Precision:** Deep obsidian (`oklch(0.14 0.01 260)`), slate borders, electric blue accent (`oklch(0.65 0.19 250)`), JetBrains Mono + Inter.
- **Editorial Elegance:** Warm cream (`oklch(0.98 0.01 60)`), charcoal body (`oklch(0.20 0.02 60)`), serif headers (*Newsreader*) + clean body sans.
- **Modern Obsidian Dark:** Neutral graphite (`#161618`), card elevation (`#1E1E22`), warm amber/gold accent (`#E5A93C`), Outfit + Inter.

---

## 4. Container Queries & Component Composition

```tsx
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs));
}

export function MetricCard({ title, value }: { title: string; value: string }) {
  return (
    <div className="@container p-4 rounded-xl bg-[var(--color-surface-card)] border border-[var(--color-surface-border)] transition duration-150 hover:border-brand-500 active:scale-[0.98] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-500">
      <div className="flex flex-col @sm:flex-row @sm:items-center @sm:justify-between gap-2">
        <p className="text-xs uppercase tracking-wider text-[var(--color-text-muted)] font-mono">{title}</p>
        <p className="text-2xl font-semibold text-[var(--color-text-primary)] font-display">{value}</p>
      </div>
    </div>
  );
}
```

---

## 5. Verification & Testing

Validate design system implementation, build output, and accessibility:
1. **Build & Bundle Verification:**
   ```bash
   npm run build
   ```
2. **Lint & Style Check:**
   ```bash
   npm run lint
   ```
3. **WCAG AA Contrast Ratio Audit:** Run Lighthouse or axe-core to ensure 100% WCAG AA compliance (minimum 4.5:1 for normal text, 3:1 for large text).
4. **Keyboard Navigation Check:** Tab through all interactive elements; verify high-contrast `focus-visible:ring-2` is active on every component.
5. **Responsive Grid Check:** Verify layouts scale without horizontal overflow across 320px, 768px, 1024px, and 1440px breakpoints.

---

## 6. Common Pitfalls & Negative Constraints

- **Never create `tailwind.config.js`:** Configure all design tokens and utilities inside CSS using `@theme` and `@utility`.
- **Never use generic AI purple/cyan templates:** Avoid stereotypical gradients; select intentional palettes reflecting the domain.
- **Never hardcode arbitrary hex values:** Avoid `bg-[#12131a]`; use semantic CSS variables and tokens from `@theme`.
- **Never use emojis in UI components:** Always use clean SVG vector icons.
- **Avoid missing focus rings:** Always supply `focus-visible:ring-2 focus-visible:ring-brand-500` on interactive elements.
