import { describe, expect, it } from "vitest";
import { ApiError, type TokenSource } from "../src/lib/api";
import { ACCOUNT_SIGN_IN_PATH, AccountApi, memberLine, statTiles, type Me } from "../src/lib/account";
import { fakeFetch, json } from "./helpers";

const me: Me = {
  id: 1,
  email: "a@b.co",
  signInMethod: "google",
  memberSince: "2026-10-03T08:00:00Z",
  historyCount: 12,
  likedCount: 3,
  aiUsedToday: 7,
  aiLimitToday: 50,
};

const tokens = (access: string | null, fresh: string | null = null): TokenSource => ({
  accessToken: async () => access,
  refreshedAccessToken: async () => fresh,
});

describe("account display", () => {
  it("writes the member line with month, year and method", () => {
    expect(memberLine(me)).toBe("Member since October 2026 · Google");
    expect(memberLine({ ...me, signInMethod: "email" })).toContain("· Email");
    expect(memberLine({ ...me, signInMethod: "apple" })).toContain("· Apple");
  });

  it("falls back when the date is bad", () => {
    expect(memberLine({ ...me, memberSince: "nope" })).toBe("Signed in with Google");
  });

  it("makes three tiles, AI as used / limit", () => {
    expect(statTiles(me)).toEqual([
      { label: "Words looked up", value: "12" },
      { label: "Liked", value: "3" },
      { label: "AI answers today", value: "7 / 50" },
    ]);
  });

  it("sends a guest to sign-in and back", () => {
    expect(ACCOUNT_SIGN_IN_PATH).toBe("/sign-in?next=/account");
  });
});

describe("AccountApi", () => {
  it("gets /api/me with the Bearer token", async () => {
    const { fetchImpl, calls } = fakeFetch(() => json(me));
    expect(await new AccountApi("", tokens("t1"), fetchImpl).me()).toEqual(me);
    expect(calls[0].url).toBe("/api/me");
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBe("Bearer t1");
  });

  it("deletes with DELETE", async () => {
    const { fetchImpl, calls } = fakeFetch(() => new Response(null, { status: 204 }));
    await new AccountApi("", tokens("t1"), fetchImpl).deleteAccount();
    expect(calls[0].init.method).toBe("DELETE");
  });

  it("refreshes once on a 401", async () => {
    const { fetchImpl, calls } = fakeFetch(() => json({}, 401), () => json(me));
    await new AccountApi("", tokens("old", "new"), fetchImpl).me();
    expect((calls[1].init.headers as Record<string, string>).Authorization).toBe("Bearer new");
  });

  it("needs sign-in without a token", async () => {
    const { fetchImpl, calls } = fakeFetch();
    await expect(new AccountApi("", tokens(null), fetchImpl).me()).rejects.toMatchObject({ kind: "signInRequired" });
    expect(calls).toHaveLength(0);
  });

  it("throws an ApiError on a server error", async () => {
    const { fetchImpl } = fakeFetch(() => json({}, 500));
    await expect(new AccountApi("", tokens("t"), fetchImpl).deleteAccount()).rejects.toBeInstanceOf(ApiError);
  });
});
