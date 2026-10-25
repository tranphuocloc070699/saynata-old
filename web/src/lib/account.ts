/**
 * The Account page's data (TASK-102.8, doc-23): GET /api/me for the profile and counts, DELETE /api/me to delete
 * the account. Same Bearer rules as SaynataApi: one refresh and one retry on a 401.
 */
import { ApiError, MESSAGES, errorFrom, type TokenSource } from "./api";

export type SignInMethod = "email" | "google" | "apple";

/** GET /api/me (backend MeSummaryService.MeView). */
export interface Me {
  id: number;
  email: string;
  signInMethod: SignInMethod;
  /** ISO instant. */
  memberSince: string;
  historyCount: number;
  likedCount: number;
  aiUsedToday: number;
  aiLimitToday: number;
}

type Fetch = typeof fetch;

export class AccountApi {
  constructor(
    private readonly baseUrl: string,
    private readonly tokens: TokenSource,
    private readonly fetchImpl: Fetch = (input, init) => fetch(input, init),
  ) {}

  async me(): Promise<Me> {
    return (await (await this.call("GET")).json()) as Me;
  }

  async deleteAccount(): Promise<void> {
    await this.call("DELETE");
  }

  private async call(method: "GET" | "DELETE"): Promise<Response> {
    const token = await this.tokens.accessToken();
    if (!token) throw new ApiError("signInRequired", MESSAGES.signIn, 401);
    let response = await this.send(method, token);
    if (response.status === 401) {
      const fresh = await this.tokens.refreshedAccessToken(token);
      if (!fresh) throw new ApiError("signInRequired", MESSAGES.signIn, 401);
      response = await this.send(method, fresh);
    }
    if (!response.ok) {
      const body = await response.json().catch(() => null);
      throw errorFrom(response.status, body, response.headers.get("Retry-After"));
    }
    return response;
  }

  private async send(method: string, token: string): Promise<Response> {
    try {
      return await this.fetchImpl(`${this.baseUrl}/api/me`, {
        method,
        headers: { Accept: "application/json", Authorization: `Bearer ${token}` },
      });
    } catch {
      throw new ApiError("network", MESSAGES.network);
    }
  }
}

const METHOD_NAMES: Record<SignInMethod, string> = { email: "Email", google: "Google", apple: "Apple" };

/** "Member since October 2026 · Google". */
export function memberLine(me: Pick<Me, "memberSince" | "signInMethod">): string {
  const date = new Date(me.memberSince);
  const month = Number.isNaN(date.getTime())
    ? ""
    : date.toLocaleDateString("en-US", { month: "long", year: "numeric", timeZone: "UTC" });
  const method = METHOD_NAMES[me.signInMethod] ?? "Email";
  return month ? `Member since ${month} · ${method}` : `Signed in with ${method}`;
}

/** The three stat tiles, in order. AI answers show as "7 / 50". */
export function statTiles(me: Pick<Me, "historyCount" | "likedCount" | "aiUsedToday" | "aiLimitToday">) {
  return [
    { label: "Words looked up", value: String(me.historyCount) },
    { label: "Liked", value: String(me.likedCount) },
    { label: "AI answers today", value: `${me.aiUsedToday} / ${me.aiLimitToday}` },
  ];
}

/** Guests are sent to sign-in, and come back here after. */
export const ACCOUNT_SIGN_IN_PATH = "/sign-in?next=/account";

export const accountApi = (tokens: TokenSource) => new AccountApi("", tokens);
