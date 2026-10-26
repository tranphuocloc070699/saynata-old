import { describe, expect, it } from "vitest";
import { chipKeyAction, type ChipKeyState, type KeyLike } from "../src/lib/chipKeys";

const key = (k: string, extra: Partial<KeyLike> = {}): KeyLike => ({
  key: k,
  code: k,
  altKey: false,
  ctrlKey: false,
  metaKey: false,
  shiftKey: false,
  ...extra,
});
const state = (extra: Partial<ChipKeyState> = {}): ChipKeyState => ({ chipCount: 3, highlight: -1, ghost: "", caretAtEnd: true, ...extra });

describe("Tab", () => {
  it("accepts the grey completion", () => {
    expect(chipKeyAction(key("Tab"), state({ ghost: "e up" }))).toEqual({ type: "acceptGhost" });
  });
  it("leaves Tab alone with no completion, with Shift, or when the caret is not at the end", () => {
    expect(chipKeyAction(key("Tab"), state())).toEqual({ type: "none" });
    expect(chipKeyAction(key("Tab", { shiftKey: true }), state({ ghost: "x" }))).toEqual({ type: "none" });
    expect(chipKeyAction(key("Tab"), state({ ghost: "x", caretAtEnd: false }))).toEqual({ type: "none" });
  });
});

describe("Alt + digit", () => {
  it("picks chip N from event.code, even when key is a symbol (Mac)", () => {
    expect(chipKeyAction(key("¡", { code: "Digit1", altKey: true }), state())).toEqual({ type: "pick", index: 0 });
    expect(chipKeyAction(key("™", { code: "Digit3", altKey: true }), state())).toEqual({ type: "pick", index: 2 });
  });
  it("does nothing for a missing chip, Digit0, or extra modifiers", () => {
    expect(chipKeyAction(key("4", { code: "Digit4", altKey: true }), state())).toEqual({ type: "none" });
    expect(chipKeyAction(key("0", { code: "Digit0", altKey: true }), state())).toEqual({ type: "none" });
    expect(chipKeyAction(key("1", { code: "Digit1", altKey: true, shiftKey: true }), state())).toEqual({ type: "none" });
    expect(chipKeyAction(key("1", { code: "Digit1" }), state())).toEqual({ type: "none" });
  });
});

describe("Arrows, Enter, Escape", () => {
  it("ArrowDown goes from the box to the first chip, then on, and wraps", () => {
    expect(chipKeyAction(key("ArrowDown"), state())).toEqual({ type: "highlight", index: 0 });
    expect(chipKeyAction(key("ArrowDown"), state({ highlight: 1 }))).toEqual({ type: "highlight", index: 2 });
    expect(chipKeyAction(key("ArrowDown"), state({ highlight: 2 }))).toEqual({ type: "highlight", index: 0 });
  });
  it("ArrowUp goes back and wraps to the last chip", () => {
    expect(chipKeyAction(key("ArrowUp"), state({ highlight: 2 }))).toEqual({ type: "highlight", index: 1 });
    expect(chipKeyAction(key("ArrowUp"), state({ highlight: 0 }))).toEqual({ type: "highlight", index: 2 });
    expect(chipKeyAction(key("ArrowUp"), state())).toEqual({ type: "highlight", index: 2 });
  });
  it("arrows move the caret as usual with no chips or when the caret is not at the end", () => {
    expect(chipKeyAction(key("ArrowDown"), state({ chipCount: 0 }))).toEqual({ type: "none" });
    expect(chipKeyAction(key("ArrowDown"), state({ caretAtEnd: false }))).toEqual({ type: "none" });
  });
  it("Enter opens only a highlighted chip; otherwise the box sends", () => {
    expect(chipKeyAction(key("Enter"), state({ highlight: 1 }))).toEqual({ type: "openHighlighted", index: 1 });
    expect(chipKeyAction(key("Enter"), state())).toEqual({ type: "none" });
    expect(chipKeyAction(key("Enter", { shiftKey: true }), state({ highlight: 1 }))).toEqual({ type: "none" });
  });
  it("Escape clears the highlight only when there is one", () => {
    expect(chipKeyAction(key("Escape"), state({ highlight: 0 }))).toEqual({ type: "clearHighlight" });
    expect(chipKeyAction(key("Escape"), state())).toEqual({ type: "none" });
  });
  it("ignores keys while an IME is composing", () => {
    expect(chipKeyAction(key("Enter", { isComposing: true }), state({ highlight: 1 }))).toEqual({ type: "none" });
  });
});
