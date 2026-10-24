/**
 * Web sign-in (TASK-102, doc-17, doc-23): the email code, Google and Apple flows of /api/auth, and the
 * browser's session in localStorage. The same rules as the iOS AuthStore: a Bearer access token, a refresh
 * token that is swapped for a new pair shortly before the access token expires, and sign-out forgets both.
 * The emailed link is app-only (it opens saynata://), so the web uses the 6-digit code.
 */
import { ApiError, MESSAGES, errorFrom, type TokenSource } from "./api";

export interface AuthUser {
  id: string;
  email: string;
}

/** POST /api/auth/verify, /google, /apple and /refresh. */
export interface TokenResponse {
  accessToken: string;
  refreshToken: string;
  /** Seconds. */
  expiresIn: number;
  user: AuthUser;
}

export interface Session {
  accessToken: string;
  refreshToken: string;
  /** Epoch milliseconds. */
  expiresAt: number;
  email: string;
}

/** Codes from AuthController whose detail is written for the user, so it is shown as it is. */
const AUTH_CODES = new Set([
  "invalid_email",
  "invalid_code",
  "invalid_id_token",
  "invalid_refresh_token",
  "provider_not_configured",
]);

async function authError(response: Response): Promise<ApiError> {
  type Body = { code?: string; detail?: string; message?: string };
  const body = (await response.json().catch(() => null)) as Body | null;
  if (body?.code && AUTH_CODES.has(body.code)) {
    const kind = body.code === "invalid_refresh_token" ? "signInRequired" : "badRequest";
    return new ApiError(kind, body.detail ?? MESSAGES.generic, response.status);
  }
  return errorFrom(response.status, body, response.headers.get("Retry-After"));
}

type Fetch = typeof fetch;

export class AuthApi {
  constructor(
    private readonly baseUrl: string,
    private readonly fetchImpl: Fetch = (input, init) => fetch(input, init),
  ) {}

  /** Emails a 6-digit code. A new email makes the account on verify, so sign-in and sign-up are one flow. */
  async sendCode(email: string): Promise<void> {
    await this.post("/api/auth/email-code", { email });
  }

  verify(email: string, code: string): Promise<TokenResponse> {
    return this.postTokens("/api/auth/verify", { email, code });
  }

  /** `nonce` is the raw nonce; the ID token holds its SHA-256 hex (makeNonce). */
  google(idToken: string, nonce: string): Promise<TokenResponse> {
    return this.postTokens("/api/auth/google", { idToken, nonce });
  }

  apple(idToken: string, nonce: string): Promise<TokenResponse> {
    return this.postTokens("/api/auth/apple", { idToken, nonce });
  }

  refresh(refreshToken: string): Promise<TokenResponse> {
    return this.postTokens("/api/auth/refresh", { refreshToken });
  }

  async signOut(refreshToken: string): Promise<void> {
    await this.post("/api/auth/sign-out", { refreshToken });
  }

  private async postTokens(path: string, body: unknown): Promise<TokenResponse> {
    return (await (await this.post(path, body)).json()) as TokenResponse;
  }

  private async post(path: string, body: unknown): Promise<Response> {
    let response: Response;
    try {
      response = await this.fetchImpl(`${this.baseUrl}${path}`, {
        method: "POST",
        headers: { Accept: "application/json", "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
    } catch {
      throw new ApiError("network", MESSAGES.network);
    }
    if (!response.ok) throw await authError(response);
    return response;
  }
}

// The browser's session.

/** Where the session is kept; localStorage in the browser, a Map in tests. Every call may throw. */
export interface SessionStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

const STORAGE_KEY = "saynata.session";
/** Refresh this long before the access token expires, so a request never goes out with a dead token. */
const REFRESH_EARLY_MS = 60_000;

/**
 * The signed-in session as a TokenSource for SaynataApi, plus subscribe/snapshot for useSyncExternalStore.
 * One refresh at a time: two requests that both find the token old share the same refresh call.
 */
export class BrowserTokens implements TokenSource {
  private listeners = new Set<() => void>();
  private refreshing: Promise<string | null> | null = null;
  private cached: Session | null | undefined;

  constructor(
    private readonly auth: AuthApi,
    private readonly storage: () => SessionStorage | null,
    private readonly now: () => number = Date.now,
  ) {}

  /** The current session, or null for a guest. The same object until it changes (useSyncExternalStore). */
  session(): Session | null {
    if (this.cached === undefined) this.cached = this.read();
    return this.cached;
  }

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  /** Called after verify, Google or Apple. */
  signedIn(response: TokenResponse): void {
    this.save({
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiresAt: this.now() + response.expiresIn * 1000,
      email: response.user.email,
    });
  }

  /** Forgets the session at once; telling the server is best effort. */
  async signOut(): Promise<void> {
    const session = this.session();
    this.save(null);
    if (session) await this.auth.signOut(session.refreshToken).catch(() => undefined);
  }

  async accessToken(): Promise<string | null> {
    const session = this.session();
    if (!session) return null;
    if (session.expiresAt - this.now() > REFRESH_EARLY_MS) return session.accessToken;
    return this.refresh();
  }

  async refreshedAccessToken(old: string): Promise<string | null> {
    const session = this.session();
    if (!session) return null;
    // Another request already refreshed while this one was out.
    if (session.accessToken !== old && session.expiresAt - this.now() > REFRESH_EARLY_MS) return session.accessToken;
    return this.refresh();
  }

  private refresh(): Promise<string | null> {
    this.refreshing ??= this.runRefresh().finally(() => {
      this.refreshing = null;
    });
    return this.refreshing;
  }

  private async runRefresh(): Promise<string | null> {
    const session = this.session();
    if (!session) return null;
    try {
      const fresh = await this.auth.refresh(session.refreshToken);
      this.signedIn(fresh);
      return fresh.accessToken;
    } catch (error) {
      // The server said the session is over: sign out. A network error keeps it for the next try.
      if (error instanceof ApiError && error.status === 401) {
        this.save(null);
        return null;
      }
      throw error;
    }
  }

  private read(): Session | null {
    try {
      const raw = this.storage()?.getItem(STORAGE_KEY);
      if (!raw) return null;
      const value = JSON.parse(raw) as Partial<Session>;
      if (
        typeof value.accessToken !== "string" ||
        typeof value.refreshToken !== "string" ||
        typeof value.expiresAt !== "number" ||
        typeof value.email !== "string"
      )
        return null;
      return value as Session;
    } catch {
      return null;
    }
  }

  private save(session: Session | null): void {
    this.cached = session;
    try {
      const storage = this.storage();
      if (session) storage?.setItem(STORAGE_KEY, JSON.stringify(session));
      else storage?.removeItem(STORAGE_KEY);
    } catch {
      // Private mode or blocked storage: the session lives only in this tab.
    }
    for (const listener of this.listeners) listener();
  }
}

function browserStorage(): SessionStorage | null {
  try {
    return typeof window === "undefined" ? null : window.localStorage;
  } catch {
    return null;
  }
}

export const authApi = new AuthApi("");
/** The one session of this tab, shared by every SaynataApi and the account UI. */
export const browserTokens = new BrowserTokens(authApi, browserStorage);

// Helpers.

/** A random nonce and its SHA-256 hex: the provider gets the hash, the backend gets the raw value (doc-17). */
export async function makeNonce(): Promise<{ raw: string; hashed: string }> {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const raw = toHex(bytes);
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(raw));
  return { raw, hashed: toHex(new Uint8Array(digest)) };
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

/** Where to go after sign-in: `?next=` only when it is a path on this site, else the homepage. */
export function safeNextPath(next: string | null | undefined): string {
  if (!next || !next.startsWith("/") || next.startsWith("//") || next.startsWith("/\\")) return "/";
  return next;
}

export function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}

export const GOOGLE_CLIENT_ID =
  process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID ??
  "324827560698-cb0snbai8ugvrvhbtbdkfp585riflmki.apps.googleusercontent.com";
export const APPLE_SERVICES_ID = process.env.NEXT_PUBLIC_APPLE_SERVICES_ID ?? "com.saynata.web";
