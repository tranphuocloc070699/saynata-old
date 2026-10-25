"use client";
/**
 * The History | Liked page (TASK-102.6): two segments, a search box, a clear-all button (asks first), rows grouped
 * by day. A row opens the text on the homepage; the star and remove buttons act at once and sync in a batch.
 * A guest sees a sign-in prompt instead of the list.
 */
import Link from "next/link";
import { useState, useSyncExternalStore } from "react";
import { groupByDay, itemKey, liveItems, searchItems, syncedAgo, type SyncItem } from "@/lib/sync";
import { useSync } from "@/lib/useSync";
import { IconButton } from "../IconButton";
import { Close, Search, Star, Trash } from "../icons";

type Tab = "history" | "liked";

export function HistoryView() {
  const { store, state, hydrated } = useSync();
  const [tab, setTab] = useState<Tab>("history");
  const [search, setSearch] = useState("");
  const now = useNow();

  if (!hydrated) return <div className="min-h-[320px]" />;
  if (!store) return <SignInPrompt />;

  const items = searchItems(liveItems(tab === "history" ? state.history : state.liked), search);
  const total = liveItems(tab === "history" ? state.history : state.liked).length;
  const groups = groupByDay(items, now);

  const clearAll = () => {
    const what = tab === "history" ? "your whole History" : "everything in Liked";
    if (!window.confirm(`Clear ${what}? This also clears it on your other devices.`)) return;
    if (tab === "history") store.clearHistory();
    else store.clearLiked();
  };

  return (
    <section className="flex flex-col gap-4">
      <h1 className="sr-only">History and Liked</h1>
      <div className="flex items-center gap-2">
        <div role="group" aria-label="List" className="flex flex-1 rounded-full bg-tag p-1">
          {(["history", "liked"] as const).map((value) => (
            <button
              key={value}
              type="button"
              aria-pressed={tab === value}
              onClick={() => setTab(value)}
              className={`min-h-9 flex-1 cursor-pointer rounded-full text-sm font-medium transition-colors ${
                tab === value ? "bg-surface text-ink shadow-sm" : "text-muted hover:text-ink"
              }`}
            >
              {value === "history" ? "History" : "Liked"}
            </button>
          ))}
        </div>
        <IconButton
          label={tab === "history" ? "Clear History" : "Clear Liked"}
          icon={<Trash />}
          disabled={total === 0}
          onClick={clearAll}
        />
      </div>

      <label className="flex min-h-11 items-center gap-2 rounded-full border border-hairline bg-surface px-4 focus-within:border-accent">
        <Search className="size-4 shrink-0 text-muted" />
        <input
          type="search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Search"
          aria-label="Search"
          className="min-w-0 flex-1 bg-transparent outline-none placeholder:text-muted"
        />
      </label>

      {groups.length === 0 ? (
        <p className="py-10 text-center text-muted">
          {search.trim()
            ? "Nothing matches your search."
            : tab === "history"
              ? "Words and sentences you look up appear here."
              : "Tap the star on a result to keep it here."}
        </p>
      ) : (
        groups.map((group) => (
          <div key={group.title} className="flex flex-col">
            <h2 className="px-1 pb-1 text-[0.7rem] font-semibold tracking-wider text-muted uppercase">{group.title}</h2>
            <ul className="flex flex-col divide-y divide-hairline rounded-2xl border border-hairline bg-surface">
              {group.items.map((item) => (
                <Row key={itemKey(item.kind, item.text)} item={item} tab={tab} liked={isLiked(state.liked, item)} store={store} />
              ))}
            </ul>
          </div>
        ))
      )}

      <p className="text-center text-xs text-muted" aria-live="off">
        {syncedAgo(state.syncedAt, now)}
        {state.queue.length > 0 && ` · ${state.queue.length} waiting to send`}
      </p>
    </section>
  );
}

function isLiked(liked: Record<string, SyncItem>, item: SyncItem): boolean {
  const row = liked[itemKey(item.kind, item.text)];
  return !!row && !row.deleted;
}

function Row({
  item,
  tab,
  liked,
  store,
}: {
  item: SyncItem;
  tab: Tab;
  liked: boolean;
  store: NonNullable<ReturnType<typeof useSync>["store"]>;
}) {
  return (
    <li className="flex items-center gap-1 pr-1 pl-4">
      <Link
        href={`/?q=${encodeURIComponent(item.text)}`}
        className="flex min-w-0 flex-1 flex-col gap-0.5 py-3 hover:text-accent"
      >
        <span className="flex items-center gap-2">
          <span className="truncate font-semibold">{item.text}</span>
          {item.chip && (
            <span className="shrink-0 rounded-full bg-tag px-2 py-0.5 text-xs font-medium text-ink-2">{item.chip}</span>
          )}
        </span>
        {item.preview && <span className="truncate font-serif text-sm text-ink-2">{item.preview}</span>}
      </Link>
      <IconButton
        variant="plain"
        label={liked ? "Remove from Liked" : "Add to Liked"}
        icon={<Star filled={liked} className="size-5" />}
        active={liked}
        aria-pressed={liked}
        onClick={() => store.toggleLike(item.kind, item.text, item.preview, item.chip)}
      />
      {tab === "history" && (
        <IconButton
          variant="plain"
          label="Remove from History"
          icon={<Close className="size-5" />}
          onClick={() => store.removeHistory(item.kind, item.text)}
        />
      )}
    </li>
  );
}

function SignInPrompt() {
  return (
    <section className="flex flex-col items-center gap-3 py-16 text-center">
      <h1 className="font-display text-2xl">Your History and Liked</h1>
      <p className="max-w-sm text-ink-2">
        Sign in to see the words and sentences you looked up, on this device and on your phone.
      </p>
      <Link
        href="/sign-in?next=/history"
        className="inline-flex min-h-11 items-center rounded-full bg-accent px-5 font-semibold text-on-accent"
      >
        Sign in
      </Link>
    </section>
  );
}

let clock = 0;

/** The time, refreshed every 10 seconds, for the day groups and "synced N s ago". It is 0 until the browser has it. */
function useNow(): number {
  return useSyncExternalStore(
    (onChange) => {
      const tick = () => {
        clock = Date.now();
        onChange();
      };
      tick();
      const id = setInterval(tick, 10_000);
      return () => clearInterval(id);
    },
    () => clock,
    () => 0,
  );
}
