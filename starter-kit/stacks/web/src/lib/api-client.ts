import { env } from '@/config/env'

/** An error from the API. Switch on `code` (stable), not on `message` (for humans). */
export class ApiError extends Error {
  readonly status: number
  readonly code: string
  readonly requestId?: string
  readonly fields?: Record<string, string>

  constructor(
    status: number,
    code: string,
    message: string,
    requestId?: string,
    fields?: Record<string, string>,
  ) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = code
    this.requestId = requestId
    this.fields = fields
  }
}

const TIMEOUT_MS = 15_000

/** fetch + JSON + timeout + Problem Details → ApiError. The only place the app calls fetch. */
export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  let response: Response
  try {
    response = await fetch(`${env.VITE_API_URL}${path}`, {
      ...init,
      headers: { 'Content-Type': 'application/json', ...init.headers },
      signal: init.signal ?? AbortSignal.timeout(TIMEOUT_MS),
    })
  } catch (e) {
    const timedOut = e instanceof DOMException && e.name === 'TimeoutError'
    throw new ApiError(0, timedOut ? 'timeout' : 'network_error', 'Cannot reach the server')
  }

  if (response.status === 204) return undefined as T
  const body: unknown = await response.json().catch(() => undefined)
  if (!response.ok) {
    const p = (body ?? {}) as {
      code?: string
      detail?: string
      requestId?: string
      fields?: Record<string, string>
    }
    throw new ApiError(
      response.status,
      p.code ?? 'http_' + response.status,
      p.detail ?? response.statusText,
      p.requestId ?? response.headers.get('X-Request-Id') ?? undefined,
      p.fields,
    )
  }
  return body as T
}
