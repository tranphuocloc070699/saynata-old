### Backend (`backend/`, Spring Boot 4, Java 21, Postgres, Flyway)

- One package per feature (`notes/`): `XController` (HTTP only) → `XService` (logic, `@Transactional`) →
  `XRepository`. DTOs are records in `XDtos`; entities never leave the service.
- Shared code only in `common/` (errors, request id, config). No `utils` grab-bag.
- Errors: throw `ApiException(status, code, message)`; `ApiExceptionHandler` makes Problem Details with
  `code` and `requestId`. New codes are snake_case and never renamed.
- Schema: new file `src/main/resources/db/migration/V<n>__<what>.sql`. `ddl-auto=validate`. Index every
  foreign key. `timestamptz`, `text`, `bigint generated always as identity`.
- `open-in-view=false`. Load what a request needs in the service (fetch join / projection), no N+1.
- Outbound HTTP: `RestClient` from the injected `RestClient.Builder` with connect + read timeouts.
- Tests: `@WebMvcTest` + `@MockitoBean` for controllers; `*IntegrationTest` with Testcontainers Postgres for
  flows. Run one: `make -C backend test T=NoteController`. Format: `make -C backend format`.
