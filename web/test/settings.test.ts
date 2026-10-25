import { beforeEach, describe, expect, it, vi } from "vitest";
import type { TokenSource } from "../src/lib/api";
import {
  DEFAULT_SETTINGS,
  SettingsStore,
  fetchAccountSettings,
  saveAccountSettings,
  translationRowOpen,
  type KeyValueStorage,
} from "../src/lib/settings";
import { fakeFetch, json } from "./helpers";

class MapStorage implements KeyValueStorage {
  map = new Map<string, string>();
  getItem(key: string) {
    return this.map.get(key) ?? null;
  }
  setItem(key: string, value: string) {
    this.map.set(key, value);
  }
}

const signedIn: TokenSource & { session(): unknown } = {
  session: () => ({}),
  accessToken: async () => "tok",
  refreshedAccessToken: async () => "tok2",
};
const guest: TokenSource & { session(): unknown } = {
  session: () => null,
  accessToken: async () => null,
  refreshedAccessToken: async () => null,
};
const account = { targetLanguage: "ko", showTranslation: "alwaysOpen", syncHistory: false };

// The tests run in node: a Map stands in for localStorage, and window only needs to take events.
let local: MapStorage;
beforeEach(() => {
  local = new MapStorage();
  vi.stubGlobal("localStorage", local);
  vi.stubGlobal("window", { dispatchEvent: () => true, addEventListener: () => undefined, removeEventListener: () => undefined });
});

describe("account settings requests", () => {
  it("loads with the Bearer token", async () => {
    const { fetchImpl, calls } = fakeFetch(() => json(account));
    expect(await fetchAccountSettings(signedIn, fetchImpl)).toEqual(account);
    expect(calls[0].url).toBe("/api/me/settings");
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBe("Bearer tok");
  });

  it("falls back for unknown values and returns null on a failed request", async () => {
    const odd = fakeFetch(() => json({ targetLanguage: "th", showTranslation: "x" }));
    expect(await fetchAccountSettings(signedIn, odd.fetchImpl)).toEqual(DEFAULT_SETTINGS);
    const failed = fakeFetch(() => json({}, 500));
    expect(await fetchAccountSettings(signedIn, failed.fetchImpl)).toBeNull();
  });

  it("does not call the server for a guest", async () => {
    const { fetchImpl, calls } = fakeFetch();
    expect(await fetchAccountSettings(guest, fetchImpl)).toBeNull();
    expect(calls).toHaveLength(0);
  });

  it("sends only the changed fields with PUT and retries once after a 401", async () => {
    const { fetchImpl, calls } = fakeFetch(() => json({}, 401), () => json(account));
    await saveAccountSettings(signedIn, { syncHistory: false }, fetchImpl);
    expect(calls[0].init.method).toBe("PUT");
    expect(JSON.parse(String(calls[0].init.body))).toEqual({ syncHistory: false });
    expect((calls[1].init.headers as Record<string, string>).Authorization).toBe("Bearer tok2");
  });
});

describe("SettingsStore", () => {
  it("starts with the defaults: Remember, sync on", () => {
    const store = new SettingsStore(guest, () => new MapStorage());
    expect(store.get()).toEqual(DEFAULT_SETTINGS);
  });

  it("keeps a guest's change in localStorage and sends nothing", () => {
    const storage = new MapStorage();
    const { fetchImpl, calls } = fakeFetch();
    const store = new SettingsStore(guest, () => storage, fetchImpl);
    store.update({ showTranslation: "collapsed", targetLanguage: "ja" });
    expect(store.get()).toMatchObject({ showTranslation: "collapsed", targetLanguage: "ja" });
    expect(new SettingsStore(guest, () => storage).get().showTranslation).toBe("collapsed");
    expect(local.getItem("saynata.targetLang")).toBe("ja");
    expect(calls).toHaveLength(0);
  });

  it("applies a signed-in change at once and sends it in the background", async () => {
    const { fetchImpl, calls } = fakeFetch(() => json(account));
    const store = new SettingsStore(signedIn, () => new MapStorage(), fetchImpl);
    store.update({ syncHistory: false });
    expect(store.get().syncHistory).toBe(false);
    await new Promise((resolve) => setTimeout(resolve));
    expect(JSON.parse(String(calls[0].init.body))).toEqual({ syncHistory: false });
  });

  it("loads the account's settings when it opens", async () => {
    const { fetchImpl } = fakeFetch(() => json(account));
    const store = new SettingsStore(signedIn, () => new MapStorage(), fetchImpl);
    await store.load();
    expect(store.get()).toEqual(account);
    expect(local.getItem("saynata.targetLang")).toBe("ko");
  });

  it("keeps the local settings when the load fails", async () => {
    const { fetchImpl } = fakeFetch(() => json({}, 500));
    const store = new SettingsStore(signedIn, () => new MapStorage(), fetchImpl);
    await store.load();
    expect(store.get()).toEqual(DEFAULT_SETTINGS);
  });
});

describe("translationRowOpen", () => {
  it("follows the mode, and Remember follows the last choice", () => {
    const storage = new MapStorage();
    expect(translationRowOpen("collapsed", storage)).toBe(false);
    expect(translationRowOpen("alwaysOpen", storage)).toBe(true);
    expect(translationRowOpen("remember", storage)).toBe(false);
    storage.setItem("saynata.translationOpen", "1");
    expect(translationRowOpen("remember", storage)).toBe(true);
  });
});
