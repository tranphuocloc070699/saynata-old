import { env } from '@/config/env'

/** Loads Sentry only when a DSN is set, so local builds and tests do not pay for it. */
export async function initSentry(): Promise<void> {
  if (!env.VITE_SENTRY_DSN) return
  const Sentry = await import('@sentry/react')
  Sentry.init({
    dsn: env.VITE_SENTRY_DSN,
    environment: env.VITE_APP_ENV,
    release: env.VITE_RELEASE, // must match the release used when uploading source maps
    // Sentry 11+: no user info, cookies or request bodies unless we add them on purpose.
    dataCollection: { userInfo: false, cookies: false, httpBodies: [] },
    integrations: [Sentry.browserTracingIntegration()],
    tracesSampleRate: env.VITE_APP_ENV === 'production' ? 0.1 : 1.0,
    tracePropagationTargets: [/^\/api\//], // sends trace headers only to our own API
  })
}
