/**
 * One search from start to end, kept out of React so it can be tested: `startState` is what the page shows at
 * once, `fetchResult` fetches and reports every later state. A word goes to GET /api/words/{word}, more to the
 * sentence stream (doc-4, doc-5). A guest gets cached and bundled answers only (doc-17).
 */
import { ApiError, MESSAGES, type Explanation, type SaynataApi, type WordResponse } from "./api";
import type { LanguageCode } from "./languages";
import { classify, cleanSelection, MAX_SENTENCE_LENGTH } from "./textKind";

export type Result =
  | { kind: "idle" }
  | { kind: "loading"; query: string }
  | { kind: "word"; query: string; word: WordResponse }
  | { kind: "sentence"; query: string; meaning: string | null; explanation: Explanation | null }
  | { kind: "error"; query: string; message: string };

export const SIGN_IN_MESSAGE =
  "Sign in to explain new text. Dictionary words and common sentences work without an account.";

export function startState(raw: string): Result {
  const text = classify(raw);
  switch (text.kind) {
    case "empty":
      return { kind: "idle" };
    case "tooLong":
      return { kind: "error", query: raw, message: `Make it shorter: up to ${MAX_SENTENCE_LENGTH} characters.` };
    case "word":
      return { kind: "loading", query: raw };
    case "sentence":
      return { kind: "sentence", query: text.text, meaning: null, explanation: null };
  }
}

/** Fetches the answer for `raw` and calls `update` with each new state. Nothing is reported after `signal` aborts. */
export async function fetchResult(
  api: Pick<SaynataApi, "lookUpWord" | "explainSentence">,
  raw: string,
  targetLang: LanguageCode,
  update: (next: (current: Result) => Result) => void,
  signal: AbortSignal,
): Promise<void> {
  const text = classify(raw);
  const report = (next: (current: Result) => Result) => {
    if (!signal.aborted) update(next);
  };
  try {
    if (text.kind === "word") {
      await explainWord(api, text.word, raw, targetLang, report, signal);
    } else if (text.kind === "sentence") {
      await explainSentence(api, text.text, raw, targetLang, report, signal);
    }
  } catch (error) {
    report(() => ({ kind: "error", query: raw, message: errorMessage(error) }));
  }
}

/** Codes of a 422 whose text says best why nothing can be explained (backend NotEnglishException). */
const NOTHING_TO_EXPLAIN = ["not_a_word", "a_name"];

/**
 * One word: the word API first. When it has nothing (200 without senses, 404 or 422), the sentence API tries it:
 * "buồn" is not an English word, but it has a meaning. Throws the error the page should show.
 */
async function explainWord(
  api: Pick<SaynataApi, "lookUpWord" | "explainSentence">,
  word: string,
  raw: string,
  targetLang: LanguageCode,
  report: (next: (current: Result) => Result) => void,
  signal: AbortSignal,
): Promise<void> {
  let wordAnswer: WordResponse | null = null;
  let wordError: unknown = null;
  try {
    const answer = await api.lookUpWord(word, signal);
    if (answer.entry?.senses?.length) {
      report(() => ({ kind: "word", query: raw, word: answer }));
      return;
    }
    wordAnswer = answer;
  } catch (error) {
    if (signal.aborted || !(error instanceof ApiError) || (error.status !== 404 && error.status !== 422)) throw error;
    wordError = error;
  }
  const sentenceText = cleanSelection(raw);
  report(() => ({ kind: "sentence", query: sentenceText, meaning: null, explanation: null }));
  try {
    await explainSentence(api, sentenceText, raw, targetLang, report, signal);
  } catch (error) {
    if (signal.aborted) return;
    if (error instanceof ApiError && error.code && NOTHING_TO_EXPLAIN.includes(error.code)) throw error;
    // Keep the word answer: sign-in and other sentence errors say less than what the word API said.
    const kept = wordAnswer;
    if (!kept) throw wordError;
    report(() => ({ kind: "word", query: raw, word: kept }));
  }
}

/** The sentence stream. Reports every state; throws when the call fails. */
async function explainSentence(
  api: Pick<SaynataApi, "lookUpWord" | "explainSentence">,
  text: string,
  raw: string,
  targetLang: LanguageCode,
  report: (next: (current: Result) => Result) => void,
  signal: AbortSignal,
): Promise<void> {
  let meaning = "";
  const sentence = (current: Result, change: Partial<Extract<Result, { kind: "sentence" }>>): Result =>
    current.kind === "sentence" ? { ...current, ...change } : current;
  const response = await api.explainSentence(
    text,
    targetLang,
    {
      onMeaningDelta: (delta) => {
        meaning += delta;
        const so = meaning;
        report((current) => sentence(current, { meaning: so }));
      },
      onMeaning: (full) => report((current) => sentence(current, { meaning: full })),
    },
    signal,
  );
  const match = response.explanation.wordMatch?.trim();
  if (match) {
    // The text means one English word or phrase: show its word card. Any failure or empty answer keeps the sentence.
    try {
      const word = await api.lookUpWord(match, signal);
      if (word.entry?.senses?.length) {
        report(() => ({ kind: "word", query: raw, word }));
        return;
      }
    } catch {
      // Fall through to the sentence result.
    }
  }
  report(() => ({
    kind: "sentence",
    query: text,
    meaning: response.explanation.meaning,
    explanation: response.explanation,
  }));
}

export function errorMessage(error: unknown): string {
  if (!(error instanceof ApiError)) return MESSAGES.generic;
  if (error.kind === "signInRequired") return SIGN_IN_MESSAGE;
  if (error.status === 404) return "This word is not in the dictionary yet. Check the spelling.";
  return error.message;
}
