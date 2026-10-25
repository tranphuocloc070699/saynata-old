import { describe, expect, it } from "vitest";
import { ghostCompletion, startChips, suggestionChips } from "../src/lib/startChips";
import type { SyncItem } from "../src/lib/sync";

const item = (kind: "word" | "sentence", text: string): SyncItem => ({ kind, text, preview: "", chip: null, at: 0, deleted: false });
const SAMPLES = ["give up", "Hold on a second."];

describe("startChips", () => {
  it("drops recent sentences", () => {
    expect(startChips([item("sentence", "Long one."), item("word", "run")], [], [])).toEqual(["run"]);
  });
  it("shows Run and run once", () => {
    expect(startChips([item("word", "Run"), item("word", "run")], ["RUN"], [])).toEqual(["Run"]);
  });
  it("skips a hot word already in recent, recent first", () => {
    expect(startChips([item("word", "swim")], ["swim", "walk"], [])).toEqual(["swim", "walk"]);
  });
  it("caps recent at 6 and the row at 10", () => {
    const recent = Array.from({ length: 9 }, (_, i) => item("word", `r${i}`));
    const hot = Array.from({ length: 9 }, (_, i) => `h${i}`);
    const chips = startChips(recent, hot, []);
    expect(chips).toHaveLength(10);
    expect(chips.slice(0, 6)).toEqual(["r0", "r1", "r2", "r3", "r4", "r5"]);
    expect(chips[6]).toBe("h0");
  });
  it("fills with samples when hot is empty, deduped", () => {
    expect(startChips([item("word", "give up")], [], SAMPLES)).toEqual(["give up", "Hold on a second."]);
  });
  it("uses samples when everything is empty", () => {
    expect(startChips([], [], SAMPLES)).toEqual(SAMPLES);
  });
});

describe("suggestionChips", () => {
  it("puts matching recent words before the server's, no duplicates", () => {
    const recent = [item("word", "Give up"), item("word", "swim"), item("sentence", "give me a hand")];
    expect(suggestionChips("gi", recent, ["give", "give up", "given"])).toEqual(["Give up", "give", "given"]);
  });
  it("matches a recent phrase from any of its words", () => {
    expect(suggestionChips("up", [item("word", "give up")], ["upset"])).toEqual(["give up", "upset"]);
  });
  it("drops the chip equal to the typed text, in any case and spacing", () => {
    expect(suggestionChips(" Run ", [item("word", "run")], ["RUN", "runway"])).toEqual(["runway"]);
  });
  it("holds at most max chips and nothing for an empty box", () => {
    const server = Array.from({ length: 12 }, (_, i) => `a${i}`);
    expect(suggestionChips("a", [], server)).toHaveLength(9);
    expect(suggestionChips("  ", [item("word", "run")], ["run"])).toEqual([]);
  });
});

describe("ghostCompletion", () => {
  it("returns the rest of the top suggestion, in its own letters", () => {
    expect(ghostCompletion("gi", "give up")).toBe("ve up");
    expect(ghostCompletion("GI", "give up")).toBe("ve up");
  });
  it("is empty when the suggestion does not start with the typed text", () => {
    expect(ghostCompletion("up", "give up")).toBe("");
    expect(ghostCompletion("give up", "give up")).toBe("");
    expect(ghostCompletion("run", undefined)).toBe("");
    expect(ghostCompletion("", "run")).toBe("");
  });
});
