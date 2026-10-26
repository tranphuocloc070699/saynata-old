import { QueryClient } from '@tanstack/react-query'
import { ApiError } from '@/lib/api-client'

export function makeQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 30_000,
        // Retry network trouble, not 4xx answers: those will not change on retry.
        retry: (count, error) =>
          count < 2 && !(error instanceof ApiError && error.status >= 400 && error.status < 500),
      },
    },
  })
}
