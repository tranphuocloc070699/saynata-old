"use client";
/**
 * The sentence result, like the iOS SentenceCard (TASK-89.2; TASK-124 mockup B: simple first, the original as one grey
 * line that opens, the better version shown open): the original with tappable words (a tap opens the
 * word in WordSheet, over the result), the simple summary ("In simple words") that grows while it streams, the key
 * words, "Better way to say it" (closed, TASK-110) when the text has a real mistake, then the target language
 * closed and last. It mounts once the first meaning piece arrives; Home shows a skeleton before that, so a text
 * that is not English never shows as a result.
 */
import { useState } from "react";
import type { Explanation } from "@/lib/api";
import { betterPieces } from "@/lib/betterDiff";
import { languageName, type LanguageCode } from "@/lib/languages";
import { rememberTranslationRow, translationRowOpen, useSettings } from "@/lib/settings";
import { useSpeech } from "@/lib/speech";
import { plainSummary, summaryLines, type SummaryLine } from "@/lib/summaryMarkup";
import { FoldedRow } from "../FoldedRow";
import { IconButton } from "../IconButton";
import { Check, Copy, Speaker, Stop } from "../icons";
import { LikeButton } from "./LikeButton";

type Props = {
  text: string;
  /** The meaning so far; null until the first piece arrives. */
  meaning: string | null;
  /** The full answer, once the stream is done. */
  explanation: Explanation | null;
  targetLang: LanguageCode;
  /** The language changed and its line is loading: only the language row waits, the rest stays. */
  translating?: boolean;
  onWord: (word: string) => void;
};

export function SentenceCard({ text: typed, meaning, explanation, targetLang, translating = false, onWord }: Props) {
  const speech = useSpeech();
  const [copied, setCopied] = useState(false);
  // TASK-124 (mockup B): the original starts as one grey line; the simple version is the headline.
  const [originalOpen, setOriginalOpen] = useState(false);
  const [{ showTranslation }] = useSettings();
  const [startOpen] = useState(() => translationRowOpen(showTranslation));
  const streaming = explanation === null;
  const summary = explanation?.meaning ?? meaning;
  // For non-English input the English version takes the headline slot (TASK-114).
  const text = explanation?.english?.trim() || typed;

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // Clipboard refused (an old browser or no permission): nothing to undo.
    }
  };

  return (
    <div className="flex flex-col gap-1">
      <article className="flex flex-col gap-3 rounded-[22px] border border-hairline bg-surface p-4 shadow-[0_1px_2px_rgb(0_0_0/0.04),0_10px_30px_-12px_rgb(31_42_38/0.18)] sm:p-5">
        <div data-reveal className="flex flex-col gap-1">
          <button
            type="button"
            onClick={() => setOriginalOpen((open) => !open)}
            aria-expanded={originalOpen}
            className="flex min-h-11 w-full cursor-pointer items-center gap-1.5 text-left text-[0.8125rem] text-muted hover:text-ink-2"
          >
            <span className="shrink-0 font-semibold">Original:</span>
            {!originalOpen && <span className="min-w-0 flex-1 truncate">{text}</span>}
            {originalOpen && <span className="flex-1" />}
            <svg
              aria-hidden="true"
              viewBox="0 0 24 24"
              className={`size-3 shrink-0 transition-transform ${originalOpen ? "rotate-180" : ""}`}
              fill="none"
              stroke="currentColor"
              strokeWidth="2.6"
              strokeLinecap="round"
            >
              <path d="M6 9l6 6 6-6" />
            </svg>
          </button>
          {originalOpen && (
            <div className="flex items-start gap-2">
              <p className="flex-1 font-serif text-[1.0625rem] leading-relaxed">
                {tokens(text).map((token, i) =>
                  token.word ? (
                    <button
                      key={i}
                      type="button"
                      onClick={() => onWord(token.word!)}
                      className="cursor-pointer rounded underline decoration-muted decoration-dotted underline-offset-4 hover:bg-chip hover:text-accent"
                    >
                      {token.text}
                    </button>
                  ) : (
                    <span key={i}>{token.text}</span>
                  ),
                )}
              </p>
              <ListenButton text={text} speech={speech} />
            </div>
          )}
        </div>
        <div data-reveal className="flex flex-col gap-1" aria-live="polite" aria-busy={streaming}>
          <div className="flex items-start gap-2">
            {summary ? (
              <Summary text={summary} streaming={streaming} headline />
            ) : (
              <div className="flex flex-1 flex-col gap-2 py-1.5" aria-label="Writing the explanation">
                <span className="h-3 w-11/12 animate-pulse rounded bg-meaning motion-reduce:animate-none" />
                <span className="h-3 w-2/3 animate-pulse rounded bg-meaning motion-reduce:animate-none" />
              </div>
            )}
            {explanation && <ListenButton text={plainSummary(explanation.meaning)} speech={speech} />}
          </div>
          <span className="text-xs text-muted">In simple words</span>
        </div>
        {explanation?.better && (
          <div data-reveal className="flex flex-col gap-1">
            <div className="h-px bg-hairline" />
            <span className="pt-2 text-[0.7rem] font-semibold tracking-wider text-muted uppercase">
              Better way to say it
            </span>
            <BetterVersion text={typed} better={explanation.better} why={explanation.betterWhy} speech={speech} />
          </div>
        )}
        {explanation && explanation.words.length > 0 && (
          <div data-reveal className="flex flex-col gap-1">
            <span className="text-[0.7rem] font-semibold tracking-wider text-muted uppercase">Words</span>
            <ul className="flex flex-col">
              {explanation.words.map((word) => (
                <li key={word.word}>
                  <button
                    type="button"
                    onClick={() => onWord(word.word)}
                    className="flex min-h-11 w-full cursor-pointer items-baseline gap-2 rounded-lg px-1 text-left hover:bg-meaning"
                  >
                    <span className="font-semibold">{word.word}</span>
                    <span className="text-xs text-muted">{word.partOfSpeech}</span>
                    <span className="flex-1 font-serif text-ink-2">{word.meaning}</span>
                  </button>
                </li>
              ))}
            </ul>
          </div>
        )}
        {explanation && targetLang !== "en" && (translating || explanation.translation) && (
          <div data-reveal>
            <FoldedRow
              title={languageName(targetLang)}
              defaultOpen={startOpen}
              onToggle={(open) => rememberTranslationRow(showTranslation, open)}
            >
              {translating ? (
                <div className="flex flex-col gap-2 py-1.5" aria-label="Loading the language line">
                  <span className="h-3 w-11/12 animate-pulse rounded bg-meaning motion-reduce:animate-none" />
                  <span className="h-3 w-1/2 animate-pulse rounded bg-meaning motion-reduce:animate-none" />
                </div>
              ) : (
                <p className="font-serif">{explanation.translation}</p>
              )}
            </FoldedRow>
          </div>
        )}
      </article>
      <div className="flex justify-end">
        {explanation && <LikeButton kind="sentence" text={typed}preview={explanation.meaning} chip={null} />}
        <IconButton
          variant="plain"
          label={copied ? "Copied" : "Copy"}
          icon={copied ? <Check /> : <Copy />}
          active={copied}
          onClick={copy}
        />
      </div>
    </div>
  );
}

/** The summary's small Markdown (bullets and bold) without its markers, like iOS SummaryMarkup. */
function Summary({ text, streaming, headline = false }: { text: string; streaming: boolean; headline?: boolean }) {
  // Lines in order; bullets next to each other share one list.
  const blocks: SummaryLine[][] = [];
  for (const line of summaryLines(text)) {
    if (!line.bullet && line.pieces.length === 0) continue;
    const last = blocks.at(-1);
    if (line.bullet && last?.[0].bullet) last.push(line);
    else blocks.push([line]);
  }
  const pieces = (line: SummaryLine) =>
    line.pieces.map((piece, i) =>
      piece.bold ? (
        <b key={i} className="font-semibold">
          {piece.text}
        </b>
      ) : (
        <span key={i}>{piece.text}</span>
      ),
    );
  return (
    <div className={`flex flex-1 flex-col gap-1.5 font-serif ${headline ? "text-[1.25rem] leading-snug" : "text-[1.0625rem] leading-relaxed"}`}>
      {blocks.map((block, b) => {
        const caret = streaming && b === blocks.length - 1;
        return block[0].bullet ? (
          <ul key={b} className="flex list-disc flex-col gap-1 pl-5">
            {block.map((line, i) => (
              <li key={i} className={caret && i === block.length - 1 ? "stream-caret" : ""}>
                {pieces(line)}
              </li>
            ))}
          </ul>
        ) : (
          <p key={b} className={caret ? "stream-caret" : ""}>
            {pieces(block[0])}
          </p>
        );
      })}
    </div>
  );
}

function BetterVersion({
  text,
  better,
  why,
  speech,
}: {
  text: string;
  better: string;
  why?: string | null;
  speech: ReturnType<typeof useSpeech>;
}) {
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(better);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      // Clipboard refused: nothing to undo.
    }
  };
  return (
    <div className="flex flex-col gap-1">
      <div className="flex items-start gap-2">
        <p className="flex-1 font-serif text-[1.0625rem] leading-relaxed">
          {betterPieces(text, better).map((piece, i) =>
            piece.changed ? (
              <b key={i} className="font-semibold">
                {piece.text}
              </b>
            ) : (
              <span key={i}>{piece.text}</span>
            ),
          )}
        </p>
        <ListenButton text={better} speech={speech} />
        <IconButton
          compact
          variant="plain"
          label={copied ? "Copied" : "Copy the better version"}
          icon={copied ? <Check /> : <Copy />}
          active={copied}
          onClick={copy}
          className="-my-1.5"
        />
      </div>
      {why && <p className="text-sm text-ink-2">{why}</p>}
    </div>
  );
}

function ListenButton({ text, speech }: { text: string; speech: ReturnType<typeof useSpeech> }) {
  const playing = speech.speaking === text;
  return (
    <IconButton
      compact
      label={playing ? "Stop" : "Listen"}
      icon={playing ? <Stop /> : <Speaker />}
      active={playing}
      onClick={() => speech.toggle(text)}
      className="-my-1.5"
    />
  );
}

/** Splits a sentence into words (tappable) and the spaces and marks between them. */
export function tokens(text: string): { text: string; word?: string }[] {
  return text.split(/([\p{L}][\p{L}'-]*)/u).filter(Boolean).map((part) =>
    /^[\p{L}]/u.test(part) ? { text: part, word: part.toLowerCase() } : { text: part },
  );
}
