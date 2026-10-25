"use client";
/** The star on a word or sentence result (TASK-102.6): adds to or removes from Liked. Signed-in users only. */
import { itemKey, type ItemKind } from "@/lib/sync";
import { useSync } from "@/lib/useSync";
import { IconButton } from "../IconButton";
import { Star } from "../icons";

export function LikeButton({
  kind,
  text,
  preview,
  chip,
}: {
  kind: ItemKind;
  text: string;
  preview: string;
  chip: string | null;
}) {
  const { store, state } = useSync();
  if (!store) return null;
  const item = state.liked[itemKey(kind, text)];
  const liked = !!item && !item.deleted;
  return (
    <IconButton
      compact
      label={liked ? "Remove from Liked" : "Add to Liked"}
      icon={<Star filled={liked} />}
      active={liked}
      aria-pressed={liked}
      onClick={() => store.toggleLike(kind, text, preview, chip)}
    />
  );
}
