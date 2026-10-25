import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError } from "../src/lib/api";
import {
  applyOp,
  emptyState,
  groupByDay,
  itemKey,
  liveItems,
  mergeItems,
  searchItems,
  syncedAgo,
  SyncStore,
  type SyncItem,
  type SyncRequest,
  type SyncResponse,
  type Transport,
} from "../src/lib/sync";

const iso = (ms: number) => new Date(ms).toISOString();
const empty: SyncResponse = { changes: { history: [], liked: [] }, cursor: 0 };

function item(text: string, at: number, extra: Partial<SyncItem> = {}): SyncItem {
  return { kind: "word", text, preview: "", chip: null, at, deleted: false, ...extra };
}

function setup(responses: (SyncResponse | Error)[] = []) {
  const requests: SyncRequest[] = [];
  const beacons: SyncRequest[] = [];
  const transport: Transport = {
    async sync(request) {
      requests.push(request);
      const next = responses.shift() ?? empty;
      if (next instanceof Error) throw next;
      return next;
    },
    beacon: (request) => beacons.push(request),
  };
  const data = new Map<string, string>();
  const storage = {
    getItem: (k: string) => data.get(k) ?? null,
    setItem: (k: string, v: string) => void data.set(k, v),
    removeItem: (k: string) => void data.delete(k),
  };
  let clock = 1_000_000;
  const store = new SyncStore("k", () => storage, transport, () => clock);
  return { store, requests, beacons, data, tick: (ms: number) => (clock += ms), storage };
}

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

describe("merge", () => {
  it("treats words as the same in any case and spacing", () => {
    expect(itemKey("word", " Give  Up ")).toBe(itemKey("word", "give up"));
    expect(itemKey("sentence", "Hi")).not.toBe(itemKey("sentence", "hi"));
  });

  it("keeps the newer row and lets the server win a tie", () => {
    const table = { [itemKey("word", "run")]: item("run", 100, { preview: "local" }) };
    expect(mergeItems(table, [item("run", 50, { preview: "old" })])[itemKey("word", "run")].preview).toBe("local");
    expect(mergeItems(table, [item("run", 100, { preview: "server" })])[itemKey("word", "run")].preview).toBe("server");
    expect(mergeItems(table, [item("run", 200, { preview: "new" })])[itemKey("word", "run")].preview).toBe("new");
  });

  it("an older add does not bring back a tombstone", () => {
    let state = applyOp(emptyState(), { type: "liked_remove", kind: "word", text: "run", at: 200 });
    state = applyOp(state, { type: "liked_add", kind: "word", text: "run", at: 100 });
    expect(liveItems(state.liked)).toEqual([]);
    state = applyOp(state, { type: "liked_add", kind: "word", text: "run", at: 300 });
    expect(liveItems(state.liked)).toHaveLength(1);
  });

  it("clear all removes older rows, and an add before the clear is ignored", () => {
    let state = applyOp(emptyState(), { type: "history_add", kind: "word", text: "a", at: 100 });
    state = applyOp(state, { type: "history_add", kind: "word", text: "b", at: 300 });
    state = applyOp(state, { type: "history_clear", at: 200 });
    expect(liveItems(state.history).map((i) => i.text)).toEqual(["b"]);
    state = applyOp(state, { type: "history_add", kind: "word", text: "c", at: 150 });
    expect(liveItems(state.history).map((i) => i.text)).toEqual(["b"]);
  });
});

describe("views", () => {
  it("sorts newest first and searches text and preview", () => {
    const list = liveItems({ a: item("apple", 1, { preview: "a fruit" }), b: item("boat", 2), c: item("cat", 3, { deleted: true }) });
    expect(list.map((i) => i.text)).toEqual(["boat", "apple"]);
    expect(searchItems(list, "FRUIT").map((i) => i.text)).toEqual(["apple"]);
    expect(searchItems(list, "  ")).toHaveLength(2);
  });

  it("groups by day", () => {
    const now = new Date(2026, 9, 25, 15, 0).getTime();
    const at = (d: number, h: number) => new Date(2026, 9, d, h).getTime();
    const groups = groupByDay([item("a", at(25, 9)), item("b", at(24, 22)), item("c", at(24, 1)), item("d", at(20, 12))], now);
    expect(groups.map((g) => g.title)).toEqual(["Today", "Yesterday", "Oct 20, 2026"]);
    expect(groups[1].items).toHaveLength(2);
  });

  it("says how long ago", () => {
    expect(syncedAgo(null, 0)).toBe("not synced yet");
    expect(syncedAgo(0, 2000)).toBe("synced just now");
    expect(syncedAgo(0, 12_000)).toBe("synced 12 s ago");
    expect(syncedAgo(0, 180_000)).toBe("synced 3 min ago");
  });
});

describe("queue", () => {
  it("shows a change at once and sends one batch after 5 seconds", async () => {
    const { store, requests } = setup();
    store.recordLookup("word", "give up", "stop trying", "verb · B1");
    store.like("word", "give up", "stop trying", "verb · B1");
    expect(liveItems(store.snapshot().history)).toHaveLength(1);
    expect(store.isLiked("word", "Give up")).toBe(true);
    expect(requests).toHaveLength(0);
    await vi.advanceTimersByTimeAsync(4900);
    expect(requests).toHaveLength(0);
    await vi.advanceTimersByTimeAsync(200);
    expect(requests).toHaveLength(1);
    expect(requests[0].ops.map((o) => o.type)).toEqual(["history_add", "liked_add"]);
    expect(requests[0].ops[0]).toMatchObject({ kind: "word", text: "give up", chip: "verb · B1" });
    expect(store.snapshot().queue).toEqual([]);
    expect(store.snapshot().syncedAt).not.toBeNull();
  });

  it("restarts the timer on each change", async () => {
    const { store, requests } = setup();
    store.recordLookup("word", "a", "", null);
    await vi.advanceTimersByTimeAsync(4000);
    store.recordLookup("word", "b", "", null);
    await vi.advanceTimersByTimeAsync(4000);
    expect(requests).toHaveLength(0);
    await vi.advanceTimersByTimeAsync(1100);
    expect(requests).toHaveLength(1);
    expect(requests[0].ops).toHaveLength(2);
  });

  it("sends at once at 20 ops", async () => {
    const { store, requests } = setup();
    for (let i = 0; i < 20; i++) store.recordLookup("word", `w${i}`, "", null);
    await vi.advanceTimersByTimeAsync(0);
    expect(requests).toHaveLength(1);
    expect(requests[0].ops).toHaveLength(20);
  });

  it("keeps the queue when the request fails, and tries again later", async () => {
    const { store, requests } = setup([new ApiError("network", "x")]);
    store.recordLookup("word", "run", "", null);
    await vi.advanceTimersByTimeAsync(5100);
    expect(requests).toHaveLength(1);
    expect(store.snapshot().queue).toHaveLength(1);
    await vi.advanceTimersByTimeAsync(30_100);
    expect(requests).toHaveLength(2);
    expect(store.snapshot().queue).toEqual([]);
  });

  it("drops a batch the server refuses with 400", async () => {
    const { store, requests } = setup([new ApiError("badRequest", "bad", 400)]);
    store.recordLookup("word", "run", "", null);
    await vi.advanceTimersByTimeAsync(5100);
    expect(requests).toHaveLength(1);
    expect(store.snapshot().queue).toEqual([]);
  });

  it("sends the queue with keepalive on pagehide and keeps it", () => {
    const { store, beacons } = setup();
    store.removeHistory("word", "run");
    store.flushOnHide();
    expect(beacons).toHaveLength(1);
    expect(beacons[0].ops[0].type).toBe("history_remove");
    expect(store.snapshot().queue).toHaveLength(1);
  });

  it("does not send on pagehide when nothing is queued", () => {
    const { store, beacons } = setup();
    store.flushOnHide();
    expect(beacons).toHaveLength(0);
  });

  it("ignores empty text", async () => {
    const { store } = setup();
    store.recordLookup("word", "   ", "", null);
    expect(store.snapshot().queue).toEqual([]);
  });
});

describe("pull", () => {
  it("pulls on start with the stored cursor and merges the rows", async () => {
    const { store, requests } = setup([
      {
        changes: {
          history: [{ kind: "word", text: "run", preview: "move fast", chip: "verb · A1", at: iso(500), deleted: false }],
          liked: [{ kind: "sentence", text: "Hi.", preview: "", chip: null, at: iso(600), deleted: false }],
        },
        cursor: 42,
      },
    ]);
    store.start();
    store.start();
    await vi.advanceTimersByTimeAsync(0);
    expect(requests).toHaveLength(1);
    expect(requests[0]).toEqual({ since: 0, ops: [] });
    expect(liveItems(store.snapshot().history)[0]).toMatchObject({ text: "run", at: 500 });
    expect(store.isLiked("sentence", "Hi.")).toBe(true);
    expect(store.snapshot().cursor).toBe(42);
  });

  it("applies a pending local change on top of an older server row", async () => {
    const { store } = setup([
      { changes: { history: [], liked: [{ kind: "word", text: "run", preview: "", chip: null, at: iso(1), deleted: false }] }, cursor: 5 },
    ]);
    store.unlike("word", "run");
    const pull = store.flush();
    await pull;
    expect(store.isLiked("word", "run")).toBe(false);
  });

  it("restores the queue and cursor from storage", async () => {
    const first = setup();
    first.store.like("word", "run", "", null);
    first.store.dispose();
    const { SyncStore: S } = await import("../src/lib/sync");
    const again = new S("k", () => first.storage, { sync: async () => empty, beacon: () => undefined });
    expect(again.snapshot().queue).toHaveLength(1);
    expect(again.isLiked("word", "run")).toBe(true);
  });
});
