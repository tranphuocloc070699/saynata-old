# 03. Backend: Spring Boot 4

Template: `stacks/backend/`. It is built and tested: `./mvnw verify` passes, and it ran against real Postgres 16.

## Structure: package by feature

```
com.example.app
├── Application.java
├── common/           ApiException, ApiExceptionHandler, RequestIdFilter   (shared, small)
└── notes/            NoteController → NoteService → NoteRepository, Note (entity), NoteDtos (records)
```

- Controller = HTTP only. Service = logic + `@Transactional`. Repository = data.
- Classes are package-private by default (`class NoteController`). Only what other features need is `public`.
  This keeps features apart without a module framework. (Spring Modulith can check it later.)
- DTOs are `record`s. Entities never leave the service, so the API does not change when the table changes.

## Rules in the template

| Topic | What the kit does | Why |
|---|---|---|
| Errors | RFC 9457 `ProblemDetail` + stable `code` + `requestId` | Clients switch on `code`. Users can quote the `requestId` |
| Validation | `@Valid` + Jakarta constraints on request records | Bad input becomes a 400 with field errors |
| Config | `application.yml` reads only `${ENV_VAR:default}` | 12-factor; the same jar runs in every environment |
| Schema | Flyway + `ddl-auto=validate` | The schema is reviewed SQL, never a Hibernate guess |
| `open-in-view` | `false` | Stops hidden lazy queries in controllers |
| Threads | `spring.threads.virtual.enabled=true` (Java 21) | Simple blocking code that still scales |
| Logs | `logging.structured.format.console=ecs` in prod | JSON lines with `request_id`, easy to search |
| Health | `/actuator/health/liveness` and `/readiness` | For Docker, the load balancer and uptime checks |
| Shutdown | `server.shutdown=graceful` | Requests in progress finish during a deploy |
| Errors to Sentry | `sentry-spring-boot-4-starter`, off when DSN is empty | |
| API docs | springdoc → `/v3/api-docs` | Generate TS/Swift clients from it, not by hand |
| Format | Spotless + google-java-format, checked in `verify` | No style talk in reviews |
| Docker | Multi-stage, layered jar, non-root user, healthcheck | Small, safe, fast rebuilds |

## Spring Boot 4 changes (agents often get these wrong)

- `@MockBean` is gone. Use `@MockitoBean` (`org.springframework.test.context.bean.override.mockito`).
- The starters are modular: `spring-boot-starter-webmvc`, `spring-boot-starter-flyway`,
  `spring-boot-starter-webmvc-test`. `@WebMvcTest` moved to `org.springframework.boot.webmvc.test.autoconfigure`.
- Testcontainers 2: `org.testcontainers.postgresql.PostgreSQLContainer`, artifacts `testcontainers-postgresql`.
- `@SpringBootTest` no longer sets up MockMvc for you. Add `@AutoConfigureMockMvc` if you need it.

## Tests

- `@WebMvcTest` + `@MockitoBean` for each controller: fast, no DB (`NoteControllerTest`).
- `*IntegrationTest` with `@Testcontainers(disabledWithoutDocker = true)` + `@ServiceConnection`:
  real Postgres, real migrations (`NoteFlowIntegrationTest`). They run in CI, and skip on a laptop without Docker.
- No `@SpringBootTest` for logic that a plain unit test can cover.

## Outbound calls (other APIs, LLMs)

- Use `RestClient` built from the injected `RestClient.Builder` (it keeps tracing). Set connect + read timeouts.
- One gate class per paid API (Saynata: `limits/ClaudeGate`). It checks limits and budget, logs cost,
  and is the only class that calls the API.

## Real examples

- `spring-projects/spring-petclinic`: the official sample, small and package-by-feature.
- Spring Boot reference: *Structured logging*, *Testcontainers*, *Graceful shutdown*, *Problem Details*.
- `spring-modulith`: when you want feature boundaries checked by tests.
- This repo: `backend/` (Saynata). Look at `limits/ClaudeGate` and `common/ApiExceptionHandler`.
