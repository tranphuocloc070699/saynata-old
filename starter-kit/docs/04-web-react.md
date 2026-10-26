# 04. Web: React + Vite + TypeScript

Template: `stacks/web/`. Built and tested: oxlint, prettier, `tsc` strict, 2 Vitest tests, and the production build.

## Structure (from bulletproof-react)

```
src/
├── app/           providers, router, query client       (app wiring)
├── config/env.ts  zod-checked import.meta.env            (the only place env is read)
├── lib/           api-client, analytics, sentry          (shared, no feature code)
├── features/
│   └── notes/     api.ts (query hooks), NotesPage.tsx, NotesPage.test.tsx
└── test/          setup, MSW server, render helper
```

Rules: a feature never imports another feature. Shared code moves to `lib/`. Imports use `@/...`.

## Rules in the template

| Topic | What the kit does | Why |
|---|---|---|
| Server state | TanStack Query hooks in `features/x/api.ts` | Caching, retries, loading and error states for free. No `useEffect` + `fetch` |
| HTTP | One `api()` function: timeout, Problem Details → `ApiError(code)` | Errors are handled the same way everywhere |
| Retries | Only for network/5xx, never for 4xx | A 400 will not fix itself |
| Config | zod schema over `import.meta.env` | A wrong config fails at start. Only `VITE_*` keys reach the browser |
| Types | `strict` + `noUncheckedIndexedAccess` | Catches `arr[0]` being `undefined` |
| Lint/format | oxlint (fast, from the Vite template) + prettier | |
| Tests | Vitest + Testing Library + MSW (`onUnhandledFrame: 'error'`) | Tests use the UI like a user does; the fake API fails on unknown calls |
| Errors | Sentry loaded **only** when a DSN is set (dynamic import) | The bundle went from 588 kB to 431 kB |
| Source maps | `build.sourcemap: 'hidden'` | Upload to Sentry; never serve them to users |
| Analytics | Typed `track()` with a tracking plan in code | No typos in event names, and no personal data |

## Good habits

- Local UI state: `useState`. Shared UI state: lift it up or use context. Add a store (Zustand) only when
  that hurts. Server data is never copied into a store.
- Forms: React Hook Form + zod (the same schema can check API input).
- Generate API types from the backend's OpenAPI (`openapi-typescript`) once you have more than 3 endpoints.
- Accessibility: query tests by role and label. If a test cannot find a button by its name, a screen reader cannot either.
- Next.js only if you need SEO or server rendering (Saynata's `web/` does: a marketing site).
  For an app behind a login, a Vite SPA is simpler.

## Real examples

- `alan2207/bulletproof-react`: structure, API layer, testing: <https://github.com/alan2207/bulletproof-react>
- TkDodo's blog, *Practical React Query*: <https://tkdodo.eu/blog/practical-react-query>
- Kent C. Dodds, *Testing Library guiding principles*.
- This repo: `admin/` (Refine + shadcn admin) and `web/` (Next.js).
