"use client";
/**
 * Web settings (TASK-102.7, doc-23). A signed-in user's settings follow the account (GET / PUT /api/me/settings);
 * a guest's stay in localStorage. A change applies at once on this browser and is sent in the background.
 * The target language keeps its own key (lib/targetLanguage.ts), so the homepage reads it as before.
 */
import { useSyncExternalStore } from "react";
import { type TokenSource } from "./api";
import { browserTokens } from "./auth";
import { DEFAULT_LANGUAGE, languageFromSaved, type LanguageCode } from "./languages";
import { readTargetLanguage, writeTargetLanguage } from "./targetLanguage";

/** The values of the backend (SettingsService.SHOW_TRANSLATION). */
export type ShowTranslation = "collapsed" | "alwaysOpen" | "remember";

export interface Settings {
  targetLanguage: LanguageCode;
  showTranslation: ShowTranslation;
  syncHistory: boolean;
}

export const DEFAULT_SETTINGS: Settings = {
  targetLanguage: DEFAULT_LANGUAGE,
  showTranslation: "remember",
  syncHistory: true,
};

export function showTranslationFromSaved(value: unknown): ShowTranslation {
  return value === "collapsed" || value === "alwaysOpen" || value === "remember" ? value : "remember";
}

const KEY = "saynata.settings";

export interface KeyValueStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

type Fetch = typeof fetch;

/** Reads the settings of the account. Returns null when the request fails (offline, signed out): keep the local ones. */
export async function fetchAccountSettings(tokens: TokenSource, fetchImpl: Fetch = fetch): Promise<Settings | null> {
  const body = await request(tokens, fetchImpl, "GET");
  return body ? fromServer(body) : null;
}

/** Sends the changed fields. Returns the settings the server kept, or null when it failed. */
export async function saveAccountSettings(
  tokens: TokenSource,
  patch: Partial<Settings>,
  fetchImpl: Fetch = fetch,
): Promise<Settings | null> {
  const body = await request(tokens, fetchImpl, "PUT", patch);
  return body ? fromServer(body) : null;
}

async function request(tokens: TokenSource, fetchImpl: Fetch, method: string, body?: unknown): Promise<unknown | null> {
  try {
    let token = await tokens.accessToken();
    if (!token) return null;
    for (let attempt = 0; attempt < 2; attempt++) {
      const headers: Record<string, string> = { Accept: "application/json", Authorization: `Bearer ${token}` };
      if (body !== undefined) headers["Content-Type"] = "application/json";
      const response = await fetchImpl("/api/me/settings", {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      if (response.status === 401 && attempt === 0) {
        token = await tokens.refreshedAccessToken(token);
        if (!token) return null;
        continue;
      }
      return response.ok ? await response.json() : null;
    }
  } catch {
    // Network or storage trouble: the change stays on this browser.
  }
  return null;
}

function fromServer(raw: unknown): Settings {
  const value = (raw ?? {}) as Record<string, unknown>;
  return {
    targetLanguage: languageFromSaved(value.targetLanguage),
    showTranslation: showTranslationFromSaved(value.showTranslation),
    syncHistory: typeof value.syncHistory === "boolean" ? value.syncHistory : DEFAULT_SETTINGS.syncHistory,
  };
}

/** The store of one browser tab: the snapshot in localStorage, the account behind it when signed in. */
export class SettingsStore {
  private snapshot: Settings | undefined;
  private listeners = new Set<() => void>();

  constructor(
    private readonly tokens: TokenSource & { session(): unknown },
    private readonly storage: () => KeyValueStorage | null,
    private readonly fetchImpl: Fetch = (input, init) => fetch(input, init),
  ) {}

  /** The same object until a value changes (useSyncExternalStore). */
  get = (): Settings => {
    this.snapshot ??= this.read();
    return this.snapshot;
  };

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    window.addEventListener("storage", this.reload);
    return () => {
      this.listeners.delete(listener);
      window.removeEventListener("storage", this.reload);
    };
  };

  /** Loads the account's settings and shows them. A guest or a failed request keeps the local ones. */
  async load(): Promise<void> {
    if (!this.tokens.session()) return;
    const remote = await fetchAccountSettings(this.tokens, this.fetchImpl);
    if (remote) this.apply(remote);
  }

  /** Applies the change now and sends it in the background; a failed send keeps the local value. */
  update(patch: Partial<Settings>): void {
    this.apply({ ...this.get(), ...patch });
    if (this.tokens.session()) void saveAccountSettings(this.tokens, patch, this.fetchImpl);
  }

  private apply(next: Settings): void {
    const current = this.get();
    if (
      current.targetLanguage === next.targetLanguage &&
      current.showTranslation === next.showTranslation &&
      current.syncHistory === next.syncHistory
    )
      return;
    this.snapshot = next;
    try {
      this.storage()?.setItem(
        KEY,
        JSON.stringify({ showTranslation: next.showTranslation, syncHistory: next.syncHistory }),
      );
    } catch {
      // Storage blocked: the values live in this tab only.
    }
    if (current.targetLanguage !== next.targetLanguage) writeTargetLanguage(next.targetLanguage);
    for (const listener of this.listeners) listener();
  }

  private reload = (): void => {
    this.snapshot = this.read();
    for (const listener of this.listeners) listener();
  };

  private read(): Settings {
    let saved: Record<string, unknown> = {};
    try {
      saved = JSON.parse(this.storage()?.getItem(KEY) ?? "{}") as Record<string, unknown>;
    } catch {
      saved = {};
    }
    return {
      targetLanguage: readTargetLanguage(),
      showTranslation: showTranslationFromSaved(saved.showTranslation),
      syncHistory: typeof saved.syncHistory === "boolean" ? saved.syncHistory : DEFAULT_SETTINGS.syncHistory,
    };
  }
}

function browserStorage(): KeyValueStorage | null {
  try {
    return typeof window === "undefined" ? null : window.localStorage;
  } catch {
    return null;
  }
}

export const settingsStore = new SettingsStore(browserTokens, browserStorage);

/** The settings and the setter. Pages call settingsStore.load() to bring in the account's values. */
export function useSettings(): [Settings, (patch: Partial<Settings>) => void] {
  const settings = useSyncExternalStore(settingsStore.subscribe, settingsStore.get, () => DEFAULT_SETTINGS);
  return [settings, settingsStore.update.bind(settingsStore)];
}

const OPEN_KEY = "saynata.translationOpen";

/** Whether a new language row starts open: always, never, or as the user left the last one ("Remember"). */
export function translationRowOpen(mode: ShowTranslation, storage: KeyValueStorage | null = browserStorage()): boolean {
  if (mode === "alwaysOpen") return true;
  if (mode === "collapsed") return false;
  try {
    return storage?.getItem(OPEN_KEY) === "1";
  } catch {
    return false;
  }
}

/** Called when the user opens or closes a language row; only "Remember" keeps it. */
export function rememberTranslationRow(
  mode: ShowTranslation,
  open: boolean,
  storage: KeyValueStorage | null = browserStorage(),
): void {
  if (mode !== "remember") return;
  try {
    storage?.setItem(OPEN_KEY, open ? "1" : "0");
  } catch {
    // Storage blocked: the row starts closed next time.
  }
}
