### Web (`web/`, React 19, Vite, TypeScript strict, TanStack Query, React Router)

- Code by feature: `src/features/<feature>/` holds its API hooks (`api.ts`), components, and tests.
  Shared code only in `src/lib/` (api client, analytics, sentry) and `src/app/` (providers, router).
  A feature never imports from another feature; move shared parts to `lib/`.
- Server data only through TanStack Query hooks in `api.ts`. No `fetch` outside `lib/api-client.ts`.
  No server data copied into `useState`.
- Config only from `src/config/env.ts` (zod-checked). Only `VITE_*` keys reach the browser: never secrets.
- Errors: `ApiError.code` decides what the UI shows; field errors from `fields`.
- Analytics: only events listed in `lib/analytics.ts` (`object_action`, past tense, no personal data).
- Tests: Vitest + Testing Library + MSW. Query by role/label like a user, not by class or test id.
  Run one file: `make -C web test F=src/features/notes/NotesPage.test.tsx`.
- `make -C web check` = oxlint + prettier + tsc + tests + build.
