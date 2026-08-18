---
title: Frontend toolchain and runtime configuration
summary: Vite, TypeScript strict and Tailwind 4, with a dev proxy that mirrors production paths and one build artefact configured at runtime.
keywords: [Vite, TypeScript, strict, Tailwind, tsconfig, path alias, dev proxy, runtime config, __RUNTIME_CONFIG__, build]
related:
  - webapp/system-shape.md
  - webapp/frontend-structure.md
  - webapp/infrastructure.md
---

# Frontend toolchain and runtime configuration

## Choosing the build toolchain

- **Vite** + `@vitejs/plugin-react`, **TypeScript strict**, **Tailwind CSS 4**
  via `@tailwindcss/vite` (CSS-first config: `@theme` / `@source`; no
  `tailwind.config.js`, no `postcss.config.js`).
- `tsconfig`: `strict: true`, plus `noUnusedLocals`, `noUnusedParameters`,
  `noFallthroughCasesInSwitch`. `any` is prohibited — use `unknown` + type
  guards. No suppression comments (`@ts-ignore`, `eslint-disable`): fix the
  root cause.
- Path alias `@/*` → `src/*` (declared in both Vite and tsconfig, kept in sync).
- `build` script is `tsc -b && vite build` — the type check is part of the
  build, not a separate optional step.

## Mirroring production paths in the dev proxy

```ts
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  server: {
    proxy: {
      "/api": "http://localhost:8080",
      "/auth": "http://localhost:8080",
    },
  },
});
```

Whatever the production reverse proxy forwards, the dev server forwards the
same — so cookies, redirects and relative URLs behave identically.

## Configuring at runtime, not at build time

Ship a `public/config.js` containing
`window.__RUNTIME_CONFIG__ = { apiBaseUrl: "" }` and let the deployment overlay
it (a mounted file, a templated asset). Resolution order:

```ts
export const env = {
  apiBaseUrl:
    window.__RUNTIME_CONFIG__?.apiBaseUrl   // deployment-provided — wins
    || import.meta.env.VITE_API_BASE_URL     // build-time fallback (dev)
    || "/api",                               // default: same-origin
};
```

One build artefact then serves every environment.
