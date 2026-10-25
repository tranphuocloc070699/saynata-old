/**
 * The small Markdown of a sentence summary, like iOS SummaryMarkup (TASK-89.3): lines that start with "- " are
 * bullets and **text** is bold. The markers are never shown. While the summary streams, an open "**" makes the
 * rest of the line bold, so the marker does not flash on screen.
 */

export type Piece = { text: string; bold: boolean };
export type SummaryLine = { bullet: boolean; pieces: Piece[] };

export function summaryLines(summary: string): SummaryLine[] {
  return summary.split("\n").map((raw) => {
    const bullet = /^\s*[-*]\s+/.test(raw);
    const line = bullet ? raw.replace(/^\s*[-*]\s+/, "") : raw;
    return { bullet, pieces: boldPieces(line) };
  });
}

/** Splits on "**": even parts are plain, odd parts are bold. An unclosed "**" makes the rest bold. */
export function boldPieces(text: string): Piece[] {
  return text
    .split("**")
    .map((part, i) => ({ text: part, bold: i % 2 === 1 }))
    .filter((piece) => piece.text.length > 0);
}

/** The summary without markers, for Listen and Copy. */
export function plainSummary(summary: string): string {
  return summaryLines(summary)
    .map((line) => line.pieces.map((piece) => piece.text).join(""))
    .join("\n");
}
