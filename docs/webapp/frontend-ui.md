---
title: Frontend styling, design tokens and forms
summary: Tailwind 4 CSS-first with semantic tokens only, class-based theming applied before React mounts, a shared component library, and forms validated on submit against named constants.
keywords: [Tailwind, design tokens, semantic colors, dark mode, custom-variant, type scale, component library, cn, tailwind-merge, forms, useState, react-hook-form, zod]
related:
  - webapp/frontend-structure.md
  - webapp/frontend-react.md
  - webapp/security-input-sql.md
---

# Frontend styling, design tokens and forms

## Styling with Tailwind and semantic tokens

- **Tailwind 4, CSS-first.** The app's CSS entry is two imports: `tailwindcss`
  and the design-token theme.
- **Semantic tokens only.** Colors are `--color-background`, `--color-card`,
  `--color-primary`, `--color-destructive`… defined in `@theme` (light) and
  overridden under `.dark`. **Never hardcode hex values or raw palette scales
  in app code.**
- If tokens are shared across platforms, build them from a token source (JSON +
  Style Dictionary) emitting the Tailwind theme, dark/light variable sets, and
  typed JS tokens.

## Switching themes

Theme switching is a `dark`/`light` class on `<html>`, applied by an inline
pre-React script in `index.html` (reads the persisted preference — no flash of
wrong theme) and mirrored by a persisted store.

In Tailwind 4 the `dark:` variant follows `prefers-color-scheme` by default —
class-based theming needs one line in the CSS entry:
`@custom-variant dark (&:where(.dark, .dark *));`

## Naming the type scale

A **small purpose-named type scale** beats a large generic one: `--text-row`
(list rows, inputs), `--text-meta` (panel titles, qualifiers), `--text-caption`
(chips, group headings). Name sizes for what they label.

## Building a shared component library

Build the component library, not per-app components: Button, Input, Modal,
Card, Skeleton, EmptyState… If a primitive is missing, add it to the shared
library, not to the app.

If you compose classes with a `cn()` helper, know what yours does: a plain join
does **not** resolve Tailwind conflicts (that is `tailwind-merge`); express
overrides as a ternary emitting one class.

## Handling forms

For apps with few forms, `useState` + a typed setter + an errors record is
sufficient and dependency-free:

```tsx
const [form, setForm] = useState<CreateOrderForm>(initialForm);
const [errors, setErrors] = useState<Partial<Record<keyof CreateOrderForm, string>>>({});

const setField = <K extends keyof CreateOrderForm>(key: K, value: CreateOrderForm[K]) => {
  setForm((prev) => ({ ...prev, [key]: value }));
  if (errors[key]) setErrors((prev) => ({ ...prev, [key]: undefined })); // clear on edit
};
```

Validate on submit against named constants (`TITLE_MAX_LENGTH`), mirror the
backend's limits. For form-heavy apps, `react-hook-form` + `zod` is the
standard upgrade path. Either way the backend re-validates everything — client
validation is UX only.
