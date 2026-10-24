import { describe, expect, it } from "vitest";
import { ApiError } from "../src/lib/api";
import {
  AuthApi,
  BrowserTokens,
  isValidEmail,
  makeNonce,
  safeNextPath,
  type SessionStorage,
  type TokenResponse,
} from "../src/lib/auth";
import { fakeFetch, json } from "./helpers";

function tokens(access: string, refresh: string, expiresIn = 900): TokenResponse {
  return { accessToken: access, refreshToken: refresh, expiresIn, user: { id: "u1", email: "a@b.co" } };
}

class MapStorage implements SessionStorage {
  map = new Map<string, string>();
  getItem(key: string) {
    return this.map.get(key) ?? null;
  }
  setItem(key: string, value: string) {
    this.map.set(key, value);
  }
  removeItem(key: string) {
    this.map.delete(key);
  }
}

describe("AuthApi", () => {
  it("sends the email for a code", async () => {
    const { fetchImpl, calls } = fakeFetch(() => new Response(null, { status: 204 }));
    await new AuthApi("", fetchImpl).sendCode("a@b.co");
    expect(calls[0].url).toBe("/api/auth/email-code");
    expect(calls[0].init.method).toBe("POST");
    expect(JSON.parse(String(calls[0].init.body))).toEqual({ email: "a@b.co" });
  });

  it("verifies the code and returns the tokens", async () => {
    const { fetchImpl, calls } = fakeFetch(() => json(tokens("A", "R")));
    const result = await new AuthApi("", fetchImpl).verify("a@b.co", "123456");
    expect(calls[0].url).toBe("/api/auth/verify");
    expect(JSON.parse(String(calls[0].init.body))).toEqual({ email: "a@b.co", code: "123456" });
    expect(result.accessToken).toBe("A");
  });

  it("sends the Google and Apple ID tokens with the raw nonce", async () => {
    const { fetchImpl, calls } = fakeFetch(
      () => json(tokens("A", "R")),
      () => json(tokens("B", "S")),
    );
    const api = new AuthApi("", fetchImpl);
    await api.google("gid", "raw1");
    await api.apple("aid", "raw2");
    expect(calls[0].url).toBe("/api/auth/google");
    expect(JSON.parse(String(calls[0].init.body))).toEqual({ idToken: "gid", nonce: "raw1" });
    expect(calls[1].url).toBe("/api/auth/apple");
    expect(JSON.parse(String(calls[1].init.body))).toEqual({ idToken: "aid", nonce: "raw2" });
  });

  it("shows the server's text for a wrong code", async () => {
    const { fetchImpl } = fakeFetch(() =>
      json({ code: "invalid_code", detail: "That code is wrong or expired." }, 400),
    );
    const error = await new AuthApi("", fetchImpl).verify("a@b.co", "000000").catch((e: unknown) => e);
    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).message).toBe("That code is wrong or expired.");
    expect((error as ApiError).kind).toBe("badRequest");
  });

  it("maps rate limits like the other endpoints", async () => {
    const { fetchImpl } = fakeFetch(() => json({ code: "rate_limited" }, 429, { "Retry-After": "120" }));
    const error = (await new AuthApi("", fetchImpl).sendCode("a@b.co").catch((e: unknown) => e)) as ApiError;
    expect(error.kind).toBe("rateLimited");
    expect(error.message).toContain("2 minutes");
  });

  it("turns a failed fetch into a network error", async () => {
    const fetchImpl = (async () => {
      throw new TypeError("offline");
    }) as typeof fetch;
    const error = (await new AuthApi("", fetchImpl).sendCode("a@b.co").catch((e: unknown) => e)) as ApiError;
    expect(error.kind).toBe("network");
  });
});

describe("BrowserTokens", () => {
  function setup(...handlers: Parameters<typeof fakeFetch>) {
    const { fetchImpl, calls } = fakeFetch(...handlers);
    const storage = new MapStorage();
    let now = 1_000_000;
    const source = new BrowserTokens(new AuthApi("", fetchImpl), () => storage, () => now);
    return { source, storage, calls, advance: (ms: number) => (now += ms) };
  }

  it("is a guest with nothing stored", async () => {
    const { source } = setup();
    expect(source.session()).toBeNull();
    expect(await source.accessToken()).toBeNull();
  });

  it("keeps the session after sign-in and tells subscribers", async () => {
    const { source, storage } = setup();
    let told = 0;
    source.subscribe(() => told++);
    source.signedIn(tokens("A", "R"));
    expect(told).toBe(1);
    expect(source.session()?.email).toBe("a@b.co");
    expect(await source.accessToken()).toBe("A");
    expect(storage.map.has("saynata.session")).toBe(true);
  });

  it("reads a stored session and drops a broken one", () => {
    const storage = new MapStorage();
    storage.setItem("saynata.session", JSON.stringify({ accessToken: "A", refreshToken: "R", expiresAt: 5, email: "x@y.z" }));
    expect(new BrowserTokens(new AuthApi(""), () => storage).session()?.email).toBe("x@y.z");
    storage.setItem("saynata.session", "{not json");
    expect(new BrowserTokens(new AuthApi(""), () => storage).session()).toBeNull();
  });

  it("refreshes shortly before the access token expires", async () => {
    const { source, calls, advance } = setup(() => json(tokens("A2", "R2")));
    source.signedIn(tokens("A", "R", 900));
    advance(900_000 - 30_000);
    expect(await source.accessToken()).toBe("A2");
    expect(calls[0].url).toBe("/api/auth/refresh");
    expect(JSON.parse(String(calls[0].init.body))).toEqual({ refreshToken: "R" });
    expect(source.session()?.refreshToken).toBe("R2");
  });

  it("shares one refresh between two requests", async () => {
    const { source, calls } = setup(() => json(tokens("A2", "R2")));
    source.signedIn(tokens("A", "R"));
    const [one, two] = await Promise.all([source.refreshedAccessToken("A"), source.refreshedAccessToken("A")]);
    expect([one, two]).toEqual(["A2", "A2"]);
    expect(calls).toHaveLength(1);
  });

  it("uses a token another request already refreshed", async () => {
    const { source, calls } = setup();
    source.signedIn(tokens("A2", "R2"));
    expect(await source.refreshedAccessToken("A")).toBe("A2");
    expect(calls).toHaveLength(0);
  });

  it("signs out when the refresh token is refused", async () => {
    const { source, storage } = setup(() => json({ code: "invalid_refresh_token", detail: "Sign in again." }, 401));
    source.signedIn(tokens("A", "R"));
    expect(await source.refreshedAccessToken("A")).toBeNull();
    expect(source.session()).toBeNull();
    expect(storage.map.has("saynata.session")).toBe(false);
  });

  it("keeps the session on a network error", async () => {
    const { source } = setup(() => {
      throw new TypeError("offline");
    });
    source.signedIn(tokens("A", "R"));
    await expect(source.refreshedAccessToken("A")).rejects.toMatchObject({ kind: "network" });
    expect(source.session()).not.toBeNull();
  });

  it("forgets the session on sign-out and tells the server", async () => {
    const { source, calls } = setup(() => new Response(null, { status: 204 }));
    source.signedIn(tokens("A", "R"));
    await source.signOut();
    expect(source.session()).toBeNull();
    expect(calls[0].url).toBe("/api/auth/sign-out");
  });

  it("signs out even when the server cannot be reached", async () => {
    const { source } = setup(() => {
      throw new TypeError("offline");
    });
    source.signedIn(tokens("A", "R"));
    await source.signOut();
    expect(source.session()).toBeNull();
  });
});

describe("helpers", () => {
  it("makes a nonce and its SHA-256 hex", async () => {
    const { raw, hashed } = await makeNonce();
    expect(raw).toMatch(/^[0-9a-f]{64}$/);
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(raw));
    expect(hashed).toBe(Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, "0")).join(""));
  });

  it("keeps ?next= only for paths on this site", () => {
    expect(safeNextPath("/?q=hello")).toBe("/?q=hello");
    expect(safeNextPath(null)).toBe("/");
    expect(safeNextPath("https://evil.example")).toBe("/");
    expect(safeNextPath("//evil.example")).toBe("/");
    expect(safeNextPath("/\\evil.example")).toBe("/");
  });

  it("checks the email shape", () => {
    expect(isValidEmail(" a@b.co ")).toBe(true);
    expect(isValidEmail("a@b")).toBe(false);
    expect(isValidEmail("a b@c.de")).toBe(false);
  });
});
