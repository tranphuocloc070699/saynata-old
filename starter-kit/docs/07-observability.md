# 07. Observability: errors, logs, traces, uptime

Start small. For a solo project, this order gives the most value for the least work:

| # | What | Tool (free tier is enough at the start) | Already in the kit |
|---|---|---|---|
| 1 | Crash and error reports | **Sentry** (backend, web, iOS) | Yes, off until you set a DSN |
| 2 | Uptime + alert | Better Stack / UptimeRobot / Healthchecks.io hitting `/actuator/health/readiness` | Endpoint yes |
| 3 | Structured logs you can search | JSON to stdout → Grafana Loki, Better Stack, or Axiom | JSON format yes |
| 4 | A request id in every log line and error | `X-Request-Id` → MDC → Problem Details | Yes |
| 5 | Metrics (latency, error rate, LLM cost) | Micrometer → Prometheus/Grafana Cloud | Add when you have users |
| 6 | Distributed traces | OpenTelemetry → Sentry, Grafana Tempo, or Honeycomb | Add when you have more than 2 services |

## Sentry setup that does not leak or flood

- `environment` (local/staging/production) and `release` (the git SHA) on **every** SDK. The release
  must match the one you used to upload source maps or dSYMs, or stack traces stay unreadable.
- Upload source maps (web, `sentry-cli sourcemaps upload` in CI) and dSYMs (iOS) on each release.
- Personal data off by default: backend `send-default-pii: false`; web Sentry 11+
  `dataCollection: { userInfo: false, cookies: false, httpBodies: [] }`; iOS `sendDefaultPii = false`.
  Attach a user **id** only, never an email.
- Traces: `0.1` in production at the start, `1.0` locally. Lower it as traffic grows (cost).
- Alert rules: "new issue" and "issue regressed". Send them to email or Slack. Do not alert on every event.

## Logging rules

- One event per line, as key=value or JSON: `note_created id=42 title_length=9`.
- Log **ids, counts, durations, codes**. Never log passwords, tokens, emails, or user text.
- Levels: `ERROR` means a human must look. `WARN` means unusual but handled. `INFO` means a business event. `DEBUG` stays off in prod.
- Every log line has `request_id` (backend) or `run_id` (jobs). With it, a user report → logs → Sentry takes one search.
- Logs go to stdout; the platform collects them. The app never writes log files.

## OpenTelemetry later

When you add it, use the Spring Boot OTLP support (Micrometer Tracing), the Sentry OTel integration,
or the OTel Java agent. Watch the key names: Micrometer puts `traceId` in MDC, while the OTel agent uses
`trace_id`. Build `RestClient` from the injected builder, or the trace headers are not sent.

## Real examples

- Sentry docs: *Releases & health*, *Source maps*, *Scrubbing sensitive data*.
- Spring Boot reference: *Structured logging*, *Tracing* (docs.spring.io/spring-boot/reference/actuator/tracing.html).
- Google SRE book, ch. 6 *Monitoring distributed systems* (the "four golden signals": latency, traffic, errors, saturation).
