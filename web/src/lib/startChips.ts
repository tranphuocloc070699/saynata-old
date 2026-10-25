import { itemKey, type SyncItem } from "./sync";

/**
 * The chips under the empty box: the user's newest words, then words many people looked up, then samples.
 * One chip per word (same word in any case and spacing). A phrase that opened as a word card is kind "word".
 */
export function startChips(recent: SyncItem[], hot: string[], samples: string[], max = 10, maxRecent = 6): string[] {
  const seen = new Set<string>();
  const chips: string[] = [];
  const add = (text: string, limit: number) => {
    if (chips.length >= limit) return;
    const key = itemKey("word", text);
    if (seen.has(key)) return;
    seen.add(key);
    chips.push(text.trim());
  };
  const words = recent.filter((item) => item.kind === "word").map((item) => item.text);
  words.forEach((text) => add(text, maxRecent));
  hot.forEach((text) => add(text, max));
  samples.forEach((text) => add(text, max));
  return chips;
}
