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

/** A recent word matches when the typed text starts it, or starts one of its words ("up" finds "give up"). */
function matchesTyped(text: string, typed: string): boolean {
  const lower = text.toLowerCase();
  return lower.startsWith(typed) || lower.split(/\s+/).some((part) => part.startsWith(typed));
}

/**
 * The chips while typing (TASK-116): the user's own recent words that match come first (they are already on
 * the device, so they show at once), then the server's suggestions. One chip per text, a chip equal to the typed
 * text is dropped, and the row holds at most `max` chips.
 */
export function suggestionChips(typed: string, recent: SyncItem[], server: string[], max = 9): string[] {
  const query = typed.trim().replace(/\s+/g, " ").toLowerCase();
  if (query === "") return [];
  const seen = new Set<string>([itemKey("word", query)]);
  const chips: string[] = [];
  const add = (text: string) => {
    const key = itemKey("word", text);
    if (chips.length >= max || seen.has(key)) return;
    seen.add(key);
    chips.push(text.trim());
  };
  recent.filter((item) => item.kind === "word" && matchesTyped(item.text, query)).forEach((item) => add(item.text));
  server.forEach(add);
  return chips;
}

/**
 * The grey text after the caret (TASK-116). Only when the top suggestion starts with what was typed (any case)
 * and is longer. It returns the part still to type, in the suggestion's own letters.
 */
export function ghostCompletion(typed: string, top: string | undefined): string {
  if (!top || typed === "" || typed !== typed.trimStart()) return "";
  if (top.length <= typed.length || !top.toLowerCase().startsWith(typed.toLowerCase())) return "";
  return top.slice(typed.length);
}
