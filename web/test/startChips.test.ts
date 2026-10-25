import { describe, expect, it } from "vitest";
import { startChips } from "../src/lib/startChips";
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
