/**
 * What a key press means for the chips and the grey completion (TASK-116). Pure, so it is tested without a
 * browser. The Composer and Home only run the action it returns.
 */

/** The part of a keyboard event that is read. A real KeyboardEvent fits. */
export type KeyLike = {
  key: string;
  code: string;
  altKey: boolean;
  ctrlKey: boolean;
  metaKey: boolean;
  shiftKey: boolean;
  isComposing?: boolean;
};

export type ChipKeyState = {
  /** How many chips are shown. */
  chipCount: number;
  /** The highlighted chip, or -1 for none. */
  highlight: number;
  /** The rest of the top suggestion shown grey, or "". */
  ghost: string;
  /** The caret is at the end of the text (an empty box counts), with nothing selected. */
  caretAtEnd: boolean;
};

export type ChipKeyAction =
  | { type: "none" }
  | { type: "acceptGhost" }
  /** Alt+digit: open chip `index` (0-based) now. */
  | { type: "pick"; index: number }
  | { type: "highlight"; index: number }
  | { type: "clearHighlight" }
  /** Enter on a highlighted chip. */
  | { type: "openHighlighted"; index: number };

const NONE: ChipKeyAction = { type: "none" };

export function chipKeyAction(event: KeyLike, state: ChipKeyState): ChipKeyAction {
  if (event.isComposing) return NONE;
  const { chipCount, highlight, ghost, caretAtEnd } = state;

  // Alt+1 ... Alt+9. event.code, not event.key: on a Mac Alt+1 makes a symbol, so key is not "1".
  if (event.altKey) {
    const match = /^Digit([1-9])$/.exec(event.code);
    const index = match ? Number(match[1]) - 1 : -1;
    const plain = !event.ctrlKey && !event.metaKey && !event.shiftKey;
    return plain && index >= 0 && index < chipCount ? { type: "pick", index } : NONE;
  }
  if (event.ctrlKey || event.metaKey) return NONE;

  switch (event.key) {
    case "Tab":
      // Taken only when there is a grey completion; otherwise Tab moves the focus as usual.
      return !event.shiftKey && ghost !== "" && caretAtEnd ? { type: "acceptGhost" } : NONE;
    case "ArrowDown":
      if (event.shiftKey || chipCount === 0 || !caretAtEnd) return NONE;
      return { type: "highlight", index: highlight + 1 >= chipCount ? 0 : highlight + 1 };
    case "ArrowUp":
      if (event.shiftKey || chipCount === 0 || !caretAtEnd) return NONE;
      return { type: "highlight", index: highlight <= 0 ? chipCount - 1 : highlight - 1 };
    case "Enter":
      return !event.shiftKey && highlight >= 0 && highlight < chipCount ? { type: "openHighlighted", index: highlight } : NONE;
    case "Escape":
      return highlight >= 0 ? { type: "clearHighlight" } : NONE;
    default:
      return NONE;
  }
}
