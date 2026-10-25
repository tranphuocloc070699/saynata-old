/**
 * History and Liked on the web (TASK-102.6, doc-22, doc-23). Every change shows at once in a local copy kept in
 * localStorage, and is queued as an op. The queue goes to POST /api/sync as one batch: ~5 s after the last change,
 * at 20 ops, and on `pagehide` (a keepalive request). The server answers with everything that changed since our
 * cursor; we merge it in, newest `at` wins, removes stay as tombstones. Ops still in the queue are applied again
 * on top of a pull, so a pending local change is never undone by an older server row.
 * The store is plain TypeScript (no React) so it can be tested with a fake transport and storage.
 */
import { ApiError, MESSAGES, errorFrom } from "./api";
import { browserTokens, type SessionStorage } from "./auth";

export type ItemKind = "word" | "sentence";

/** One History or Liked row. `at` is epoch milliseconds. A deleted row is a tombstone, kept so an older add loses. */
export interface SyncItem {
  kind: ItemKind;
  text: string;
  preview: string;
  chip: string | null;
  at: number;
  deleted: boolean;
}

export type OpType = "history_add" | "history_remove" | "history_clear" | "liked_add" | "liked_remove";

export interface SyncOp {
  type: OpType;
  kind?: ItemKind;
  text?: string;
  preview?: string;
  chip?: string | null;
  at: number;
}

/** The bodies of POST /api/sync (backend SyncModels). The server sends `at` as an ISO string. */
export interface WireOp extends Omit<SyncOp, "at"> {
  at: string;
}
export interface WireItem extends Omit<SyncItem, "at"> {
  at: string;
}
export interface SyncRequest {
  since: number;
  ops: WireOp[];
}
export interface SyncResponse {
  changes: { history: WireItem[]; liked: WireItem[] };
  cursor: number;
}

export interface SyncState {
  history: Record<string, SyncItem>;
  liked: Record<string, SyncItem>;
  queue: SyncOp[];
  /** Send back as `since`. */
  cursor: number;
  /** When the last sync finished (epoch ms), or null. */
  syncedAt: number | null;
  /** The newest "clear all" we know of: an add that is not newer than it is ignored. */
  clearedAt: number;
}

export interface Transport {
  sync(request: SyncRequest): Promise<SyncResponse>;
  /** Fire and forget, for `pagehide`. */
  beacon(request: SyncRequest): void;
}

export const DEBOUNCE_MS = 5000;
export const FLUSH_AT = 20;
/** The backend takes at most this many ops in one request. */
export const MAX_OPS = 200;
const RETRY_MS = 30_000;
const MAX_TEXT = 500;
const MAX_PREVIEW = 300;
const MAX_CHIP = 40;

export function emptyState(): SyncState {
  return { history: {}, liked: {}, queue: [], cursor: 0, syncedAt: null, clearedAt: 0 };
}

/** Words are the same word in any case and spacing (like the server); a sentence keeps its case. */
export function itemKey(kind: ItemKind, text: string): string {
  const clean = text.trim().replace(/\s+/g, " ");
  return `${kind}\u0000${kind === "word" ? clean.toLowerCase() : clean}`;
}

function toItem(op: SyncOp): SyncItem {
  return {
    kind: op.kind!,
    text: op.text!.trim(),
    preview: op.preview ?? "",
    chip: op.chip ?? null,
    at: op.at,
    deleted: false,
  };
}

/** Applies one op to a copy of the state. A change older than the row it meets loses. */
export function applyOp(state: SyncState, op: SyncOp): SyncState {
  if (op.type === "history_clear") {
    const history: Record<string, SyncItem> = {};
    for (const [key, item] of Object.entries(state.history)) {
      history[key] = item.at <= op.at && !item.deleted ? { ...item, at: op.at, deleted: true } : item;
    }
    return { ...state, history, clearedAt: Math.max(state.clearedAt, op.at) };
  }
  if (!op.kind || !op.text) return state;
  const isHistory = op.type.startsWith("history");
  const table = isHistory ? state.history : state.liked;
  const key = itemKey(op.kind, op.text);
  const existing = table[key];
  if (existing && op.at < existing.at) return state;
  const add = op.type.endsWith("_add");
  if (add && isHistory && op.at <= state.clearedAt) return state;
  const next: SyncItem = add
    ? toItem(op)
    : { ...(existing ?? toItem(op)), at: op.at, deleted: true };
  const updated = { ...table, [key]: next };
  return isHistory ? { ...state, history: updated } : { ...state, liked: updated };
}

/** Merges rows from the server into a table: the newer `at` wins, and the server wins a tie. */
export function mergeItems(table: Record<string, SyncItem>, incoming: SyncItem[]): Record<string, SyncItem> {
  const merged = { ...table };
  for (const item of incoming) {
    const key = itemKey(item.kind, item.text);
    const existing = merged[key];
    if (!existing || item.at >= existing.at) merged[key] = item;
  }
  return merged;
}

function fromWire(item: WireItem): SyncItem {
  return { ...item, chip: item.chip ?? null, preview: item.preview ?? "", at: Date.parse(item.at) };
}

function toWire(op: SyncOp): WireOp {
  const wire: WireOp = { type: op.type, at: new Date(op.at).toISOString() };
  if (op.type !== "history_clear") {
    wire.kind = op.kind;
    wire.text = op.text?.slice(0, MAX_TEXT);
    wire.preview = op.preview?.slice(0, MAX_PREVIEW);
    wire.chip = op.chip ? op.chip.slice(0, MAX_CHIP) : null;
  }
  return wire;
}

/** The local copy plus the queue. One store per signed-in account. */
export class SyncStore {
  private state: SyncState;
  private listeners = new Set<() => void>();
  private timer: ReturnType<typeof setTimeout> | null = null;
  private inflight: Promise<void> | null = null;
  private started = false;
  /** A flush failed and the user has not changed anything since: the next change tries at once. */
  failed = false;

  constructor(
    private readonly storageKey: string,
    private readonly storage: () => SessionStorage | null,
    private readonly transport: Transport,
    private readonly now: () => number = Date.now,
  ) {
    this.state = this.read();
  }

  // Reading.

  /** The same object until something changes (useSyncExternalStore). */
  snapshot = (): SyncState => this.state;

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  isLiked(kind: ItemKind, text: string): boolean {
    const item = this.state.liked[itemKey(kind, text)];
    return !!item && !item.deleted;
  }

  // Changes. Each shows at once and is queued.

  recordLookup(kind: ItemKind, text: string, preview: string, chip: string | null): void {
    this.enqueue({ type: "history_add", kind, text, preview, chip, at: this.now() });
  }

  removeHistory(kind: ItemKind, text: string): void {
    this.enqueue({ type: "history_remove", kind, text, at: this.now() });
  }

  clearHistory(): void {
    this.enqueue({ type: "history_clear", at: this.now() });
  }

  like(kind: ItemKind, text: string, preview: string, chip: string | null): void {
    this.enqueue({ type: "liked_add", kind, text, preview, chip, at: this.now() });
  }

  unlike(kind: ItemKind, text: string): void {
    this.enqueue({ type: "liked_remove", kind, text, at: this.now() });
  }

  toggleLike(kind: ItemKind, text: string, preview: string, chip: string | null): void {
    if (this.isLiked(kind, text)) this.unlike(kind, text);
    else this.like(kind, text, preview, chip);
  }

  clearLiked(): void {
    for (const item of Object.values(this.state.liked)) {
      if (!item.deleted) this.unlike(item.kind, item.text);
    }
  }

  // Syncing.

  /** Pull on page load and flush on `pagehide`; once per store. */
  start(): void {
    if (this.started) return;
    this.started = true;
    if (typeof window !== "undefined") window.addEventListener("pagehide", () => this.flushOnHide());
    void this.flush();
  }

  /** Sends the queue (at most MAX_OPS) and merges the answer. Without ops it is a plain pull. */
  flush(): Promise<void> {
    this.cancelTimer();
    this.inflight ??= this.run().finally(() => {
      this.inflight = null;
      if (this.state.queue.length >= FLUSH_AT && !this.failed) void this.flush();
      else if (this.state.queue.length > 0) this.schedule(this.failed ? RETRY_MS : DEBOUNCE_MS);
    });
    return this.inflight;
  }

  /** `pagehide`: the answer cannot be waited for, so the ops stay queued; the server accepts a repeat. */
  flushOnHide(): void {
    this.cancelTimer();
    if (this.state.queue.length === 0) return;
    this.transport.beacon({ since: this.state.cursor, ops: this.state.queue.slice(0, MAX_OPS).map(toWire) });
  }

  dispose(): void {
    this.cancelTimer();
  }

  private async run(): Promise<void> {
    const sent = this.state.queue.slice(0, MAX_OPS);
    try {
      const response = await this.transport.sync({ since: this.state.cursor, ops: sent.map(toWire) });
      this.failed = false;
      this.afterSync(sent.length, response);
    } catch (error) {
      this.failed = true;
      // The server refused the batch itself (400): sending it again would fail again, so drop it.
      if (error instanceof ApiError && error.status === 400) {
        this.failed = false;
        this.commit({ ...this.state, queue: this.state.queue.slice(sent.length) });
      }
    }
  }

  private afterSync(sentCount: number, response: SyncResponse): void {
    // Ops added while the request was out stay queued; the sent ones are on the server now.
    const queue = this.state.queue.slice(sentCount);
    let next: SyncState = {
      ...this.state,
      queue,
      history: mergeItems(this.state.history, response.changes.history.map(fromWire)),
      liked: mergeItems(this.state.liked, response.changes.liked.map(fromWire)),
      cursor: Math.max(this.state.cursor, response.cursor),
      syncedAt: this.now(),
    };
    for (const op of queue) next = applyOp(next, op);
    this.commit(next);
  }

  private enqueue(op: SyncOp): void {
    if (op.type !== "history_clear" && (!op.text || !op.text.trim())) return;
    const next = applyOp(this.state, op);
    this.commit({ ...next, queue: [...this.state.queue, op] });
    if (this.state.queue.length >= FLUSH_AT) void this.flush();
    else this.schedule(DEBOUNCE_MS);
  }

  private schedule(ms: number): void {
    this.cancelTimer();
    this.timer = setTimeout(() => void this.flush(), ms);
  }

  private cancelTimer(): void {
    if (this.timer !== null) clearTimeout(this.timer);
    this.timer = null;
  }

  private commit(next: SyncState): void {
    this.state = next;
    try {
      this.storage()?.setItem(this.storageKey, JSON.stringify(next));
    } catch {
      // Storage full or blocked: the copy lives in this tab only.
    }
    for (const listener of this.listeners) listener();
  }

  private read(): SyncState {
    try {
      const raw = this.storage()?.getItem(this.storageKey);
      if (!raw) return emptyState();
      const value = JSON.parse(raw) as Partial<SyncState>;
      return { ...emptyState(), ...value, queue: Array.isArray(value.queue) ? value.queue : [] };
    } catch {
      return emptyState();
    }
  }
}

// Views of the state, for the History page.

/** Live rows of one table, newest first. */
export function liveItems(table: Record<string, SyncItem>): SyncItem[] {
  return Object.values(table)
    .filter((item) => !item.deleted)
    .sort((a, b) => b.at - a.at);
}

/** Rows whose text or preview contain the search, ignoring case. */
export function searchItems(items: SyncItem[], search: string): SyncItem[] {
  const needle = search.trim().toLowerCase();
  if (!needle) return items;
  return items.filter((item) => item.text.toLowerCase().includes(needle) || item.preview.toLowerCase().includes(needle));
}

export interface DayGroup {
  /** "Today", "Yesterday" or a date such as "Oct 23, 2026". */
  title: string;
  items: SyncItem[];
}

/** Groups rows (already newest first) by calendar day in the local time zone. */
export function groupByDay(items: SyncItem[], now: number, locale = "en-US"): DayGroup[] {
  const dayStart = (ms: number) => {
    const d = new Date(ms);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  };
  const today = dayStart(now);
  const yesterday = dayStart(today - 1);
  const groups: DayGroup[] = [];
  for (const item of items) {
    const day = dayStart(item.at);
    const title =
      day === today
        ? "Today"
        : day === yesterday
          ? "Yesterday"
          : new Date(item.at).toLocaleDateString(locale, { year: "numeric", month: "short", day: "numeric" });
    const last = groups[groups.length - 1];
    if (last && last.title === title) last.items.push(item);
    else groups.push({ title, items: [item] });
  }
  return groups;
}

/** "just now", "12 s ago", "3 min ago", "2 h ago". */
export function syncedAgo(syncedAt: number | null, now: number): string {
  if (syncedAt === null) return "not synced yet";
  const seconds = Math.max(0, Math.round((now - syncedAt) / 1000));
  if (seconds < 5) return "synced just now";
  if (seconds < 60) return `synced ${seconds} s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `synced ${minutes} min ago`;
  return `synced ${Math.floor(minutes / 60)} h ago`;
}

// The browser transport and the stores of this tab.

function headers(token: string): Record<string, string> {
  return { Accept: "application/json", "Content-Type": "application/json", Authorization: `Bearer ${token}` };
}

export const browserTransport: Transport = {
  async sync(request) {
    const post = async (token: string) => {
      try {
        return await fetch("/api/sync", { method: "POST", headers: headers(token), body: JSON.stringify(request) });
      } catch {
        throw new ApiError("network", MESSAGES.network);
      }
    };
    const token = await browserTokens.accessToken();
    if (!token) throw new ApiError("signInRequired", MESSAGES.signIn, 401);
    let response = await post(token);
    if (response.status === 401) {
      const fresh = await browserTokens.refreshedAccessToken(token);
      if (!fresh) throw new ApiError("signInRequired", MESSAGES.signIn, 401);
      response = await post(fresh);
    }
    if (!response.ok) {
      const body = (await response.json().catch(() => null)) as { code?: string; detail?: string } | null;
      throw errorFrom(response.status, body, response.headers.get("Retry-After"));
    }
    return (await response.json()) as SyncResponse;
  },
  beacon(request) {
    // No time to refresh: use the token only if the session has one that is still valid.
    const session = browserTokens.session();
    if (!session || session.expiresAt <= Date.now()) return;
    try {
      void fetch("/api/sync", {
        method: "POST",
        keepalive: true,
        headers: headers(session.accessToken),
        body: JSON.stringify(request),
      }).catch(() => undefined);
    } catch {
      // The page is closing; the ops stay queued for the next visit.
    }
  },
};

const stores = new Map<string, SyncStore>();

/** The store of one account in this tab; the copy in localStorage is per email, so accounts never mix. */
export function syncStoreFor(email: string): SyncStore {
  let store = stores.get(email);
  if (!store) {
    store = new SyncStore(
      `saynata.sync.${email.toLowerCase()}`,
      () => {
        try {
          return typeof window === "undefined" ? null : window.localStorage;
        } catch {
          return null;
        }
      },
      browserTransport,
    );
    stores.set(email, store);
  }
  return store;
}
