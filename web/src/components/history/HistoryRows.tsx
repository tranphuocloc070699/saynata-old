"use client";
/**
 * The History row and the glass card around a day's rows (TASK-102.8, doc-23). Shared by /history and the Account
 * page so both look the same. Like iOS SavedItemRow: a word is bold with its chip, a sentence is serif and stops at
 * two lines, then the short meaning. The star and remove buttons act at once and sync in a batch.
 */
import Link from "next/link";
import type { ReactNode } from "react";
import { itemKey, type SyncItem, type SyncStore } from "@/lib/sync";
import { IconButton } from "../IconButton";
import { Close, Star } from "../icons";

/** Translucent surface: the surface colour with some alpha, blurred, a hairline and soft corners. */
export const GLASS = "border border-hairline bg-surface/70 backdrop-blur-xl";

export type RowTab = "history" | "liked";

export function GlassList({ children }: { children: ReactNode }) {
  return <ul className={`flex flex-col divide-y divide-hairline overflow-hidden rounded-2xl shadow-sm ${GLASS}`}>{children}</ul>;
}

export function HistoryRow({
  item,
  tab,
  liked,
  store,
}: {
  item: SyncItem;
  tab: RowTab;
  liked: boolean;
  store: SyncStore;
}) {
  return (
    <li className="flex items-center gap-1 pr-1 pl-4">
      <Link
        href={`/?q=${encodeURIComponent(item.text)}`}
        className="flex min-w-0 flex-1 flex-col gap-1 py-3 hover:text-accent"
      >
        {item.kind === "sentence" ? (
          <span className="line-clamp-2 font-serif text-base">{item.text}</span>
        ) : (
          <span className="flex items-center gap-2">
            <span className="truncate font-semibold">{item.text}</span>
            {item.chip && (
              <span className="shrink-0 rounded-full bg-chip px-2 py-0.5 text-xs font-medium text-accent">{item.chip}</span>
            )}
          </span>
        )}
        {item.preview && <span className="line-clamp-2 text-sm text-ink-2">{item.preview}</span>}
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

export function isLiked(liked: Record<string, SyncItem>, item: SyncItem): boolean {
  const row = liked[itemKey(item.kind, item.text)];
  return !!row && !row.deleted;
}
