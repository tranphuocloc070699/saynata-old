/**
 * Error reporting with Sentry (TASK-128.5), set up the "shared environment" way from the Sentry docs: an extension
 * shares the page with websites that may run their own Sentry, so there is no Sentry.init and no integration that
 * hooks global state. The background worker owns the one client. Empty VITE_SENTRY_DSN = reporting is off.
 * Privacy rule (TASK-128): no breadcrumbs, no page URL and no request data, so selected text never leaves.
 */
import {
  BrowserClient,
  defaultStackParser,
  getDefaultIntegrations,
  makeFetchTransport,
  Scope,
} from "@sentry/browser";

/** Default integrations that read or patch globals; the docs say to leave them out in an extension. */
const GLOBAL_INTEGRATIONS = [
  "BrowserApiErrors",
  "BrowserSession",
  "Breadcrumbs",
  "ConversationId",
  "GlobalHandlers",
  "FunctionToString",
  "HttpContext",
];

export function sentryIntegrations(): ReturnType<typeof getDefaultIntegrations> {
  return getDefaultIntegrations({}).filter((integration) => !GLOBAL_INTEGRATIONS.includes(integration.name));
}

export type Report = (error: unknown) => void;

/** Starts the client and returns the function that sends one error. Without a DSN it does nothing. */
export function startSentry(dsn = import.meta.env.VITE_SENTRY_DSN as string | undefined, release?: string): Report {
  if (!dsn) return () => {};
  const client = new BrowserClient({
    dsn,
    release,
    environment: import.meta.env.MODE,
    transport: makeFetchTransport,
    stackParser: defaultStackParser,
    integrations: sentryIntegrations(),
    beforeSend(event) {
      delete event.request;
      delete event.breadcrumbs;
      return event;
    },
  });
  const scope = new Scope();
  scope.setClient(client);
  client.init(); // after setClient, as the docs say
  return (error) => scope.captureException(error);
}
