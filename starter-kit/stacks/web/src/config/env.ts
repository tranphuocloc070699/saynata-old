import { z } from 'zod'

// All config in one place, checked at start. A missing or wrong value fails loudly, not later.
const schema = z.object({
  VITE_APP_ENV: z.enum(['local', 'staging', 'production']).default('local'),
  VITE_API_URL: z.string().default(''),
  VITE_SENTRY_DSN: z.string().default(''),
  VITE_GA4_ID: z.string().default(''),
  VITE_RELEASE: z.string().default('dev'),
})

export const env = schema.parse(import.meta.env)
