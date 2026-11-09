/**
 * The Sentry options the browser, server and edge inits share (TASK-128.4, doc-23). Empty NEXT_PUBLIC_SENTRY_DSN =
 * Sentry is off. Privacy rule (TASK-128): looked-up text never leaves the app, so no query strings (the home page
 * keeps the text in ?q=), no request or response bodies, no cookies, and the word in GET /api/words/{word} is replaced.
 */
import type * as Sentry from "@sentry/nextjs";
import type { Breadcrumb, ErrorEvent } from "@sentry/nextjs";

/** The span beforeSendSpan gets (@sentry/nextjs does not export the type by name). */
export type SpanJSON = Parameters<NonNullable<NonNullable<Parameters<typeof Sentry.init>[0]>["beforeSendSpan"]>>[0];

const WORD_PATH = /\/api\/words\/(?!hot(?:[/?#]|$))[^/?#\s]+/g;
const QUERY = /\?[^#\s"']*/g;

/** A URL (or a span name that holds one) without its query string and without the looked-up word. */
export function scrubUrl(text: string): string {
  return text.replace(QUERY, "").replace(WORD_PATH, "/api/words/:word");
}

function scrubFields(record: Record<string, unknown> | undefined, keys: readonly string[]) {
  if (!record) return;
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string") record[key] = scrubUrl(value);
  }
}

const URL_KEYS = ["url", "from", "to", "http.url", "url.full", "http.target", "url.path"] as const;

export function scrubEvent(event: ErrorEvent): ErrorEvent {
  if (event.request) {
    scrubFields(event.request as Record<string, unknown>, ["url"]);
    delete event.request.query_string;
  }
  if (event.transaction) event.transaction = scrubUrl(event.transaction);
  return event;
}

export function scrubBreadcrumb(breadcrumb: Breadcrumb): Breadcrumb {
  scrubFields(breadcrumb.data, URL_KEYS);
  if (breadcrumb.category === "navigation" && breadcrumb.message) breadcrumb.message = scrubUrl(breadcrumb.message);
  return breadcrumb;
}

export function scrubSpan(span: SpanJSON): SpanJSON {
  span.name = scrubUrl(span.name);
  scrubFields(span.attributes, [...URL_KEYS, "http.query"]);
  return span;
}

export const sentryOptions = {
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN || undefined,
  environment: process.env.NODE_ENV,
  // All traces in dev, 10% in production. Raise it if the free span quota allows.
  tracesSampleRate: process.env.NODE_ENV === "development" ? 1.0 : 0.1,
  dataCollection: { userInfo: false, cookies: false, httpBodies: [], urlQueryParams: false },
  beforeSend: scrubEvent,
  beforeBreadcrumb: scrubBreadcrumb,
  beforeSendSpan: scrubSpan,
};
