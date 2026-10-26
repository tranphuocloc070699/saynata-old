import { env } from '@/config/env'

/**
 * The tracking plan. Every event the app sends is listed here, so names stay consistent and
 * nobody sends personal data by accident. Names: object_action, past tense, snake_case.
 * Properties: ids, counts, enums. Never free text, emails, or names.
 */
type Events = {
  note_created: { title_length: number }
  note_opened: { note_id: number }
}

declare global {
  interface Window {
    gtag?: (...args: unknown[]) => void
  }
}

export function track<E extends keyof Events>(event: E, props: Events[E]): void {
  if (window.gtag) {
    window.gtag('event', event, props)
  } else if (env.VITE_APP_ENV === 'local') {
    console.debug('[analytics]', event, props)
  }
}
