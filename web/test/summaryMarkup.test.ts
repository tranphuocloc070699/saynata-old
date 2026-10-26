import { describe, expect, it } from "vitest";
import { plainSummary, summaryLines } from "../src/lib/summaryMarkup";

const bold = (summary: string) =>
  summaryLines(summary).flatMap((line) => line.pieces.filter((piece) => piece.bold).map((piece) => piece.text));

describe("summaryLines", () => {
  it("leaves a plain line as it is", () => {
    expect(summaryLines("I do not know what to choose.")).toEqual([
      { bullet: false, pieces: [{ text: "I do not know what to choose.", bold: false }] },
    ]);
  });

  it("drops the bold and bullet markers", () => {
    const lines = summaryLines("Your **career** is at risk.\n- Use **private distribution**.\n- Leave.");
    expect(lines.map((line) => line.bullet)).toEqual([false, true, true]);
    expect(bold("Your **career** is at risk.\n- Use **private distribution**.")).toEqual(["career", "private distribution"]);
  });

  it("makes the rest bold while a ** is still open (streaming)", () => {
    expect(bold("A ban could hurt your **care")).toEqual(["care"]);
  });
});

describe("plainSummary", () => {
  it("has no markers, for Listen", () => {
    expect(plainSummary("Gist.\n- **One** idea.\n- Two.")).toBe("Gist.\nOne idea.\nTwo.");
    expect(plainSummary("This is my life, so please do not make it a **mess**.")).toBe(
      "This is my life, so please do not make it a mess.",
    );
  });
});
