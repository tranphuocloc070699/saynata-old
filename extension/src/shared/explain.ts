/** One explanation from start to end: word or sentence, then the events for the card. Used by the service worker. */
import { ApiError, MESSAGES, type SaynataApi, type WordResponse } from "./api";
import type { ExplainEvent, ExplainRequest } from "./messages";
import { classify, cleanSelection, MAX_SENTENCE_LENGTH } from "./textKind";

export async function explain(
  api: SaynataApi,
  request: ExplainRequest,
  emit: (event: ExplainEvent) => void,
  signal?: AbortSignal,
): Promise<void> {
  const text = classify(request.text);
  try {
    switch (text.kind) {
      case "empty":
        emit({ type: "error", kind: "empty", message: "Select some English text first." });
        return;
      case "tooLong":
        emit({ type: "error", kind: "tooLong", message: `Select up to ${MAX_SENTENCE_LENGTH} characters.` });
        return;
      case "word":
        await explainWord(api, request, text.word, emit, signal);
        return;
      case "sentence":
        await explainSentence(api, request, text.text, emit, signal);
        return;
    }
  } catch (error) {
    if (signal?.aborted) return;
    if (error instanceof ApiError) emit({ type: "error", kind: error.kind, message: error.message });
    else emit({ type: "error", kind: "server", message: MESSAGES.generic });
  }
}

/** Codes of a 422 whose text says best why nothing can be explained (backend NotEnglishException). */
const NOTHING_TO_EXPLAIN = ["not_a_word", "a_name"];

/**
 * One word. When the word API has nothing for it (200 without senses or terms, 404 or 422), the sentence API tries it: "buồn"
 * is not an English word, but it has a meaning. If that fails the word answer stays, except a 422 with a code in
 * NOTHING_TO_EXPLAIN, whose server text is the better message. Throws the error the card should show.
 */
async function explainWord(
  api: SaynataApi,
  request: ExplainRequest,
  word: string,
  emit: (event: ExplainEvent) => void,
  signal?: AbortSignal,
): Promise<void> {
  let wordError: unknown = null;
  let empty: WordResponse | null = null;
  try {
    const response = await api.lookUpWord(word, signal);
    if (response.entry?.senses?.length || response.terms?.length) {
      emit({ type: "word", response });
      return;
    }
    empty = response;
  } catch (error) {
    if (signal?.aborted || !(error instanceof ApiError) || (error.status !== 404 && error.status !== 422)) throw error;
    wordError = error;
  }
  try {
    await explainSentence(api, request, cleanSelection(request.text), emit, signal);
  } catch (error) {
    if (signal?.aborted) return;
    if (error instanceof ApiError && error.code && NOTHING_TO_EXPLAIN.includes(error.code)) throw error;
    if (empty) emit({ type: "word", response: empty }); // the card says "not an English word"
    else throw wordError; // keep the word error: the sentence call said nothing better
  }
}

/**
 * The sentence stream (TASK-114.4). When the answer names a wordMatch, its word card replaces the sentence result;
 * if that lookup fails or has no senses, the sentence result is shown. Throws when the sentence call fails.
 */
async function explainSentence(
  api: SaynataApi,
  request: ExplainRequest,
  text: string,
  emit: (event: ExplainEvent) => void,
  signal?: AbortSignal,
): Promise<void> {
  const response = await api.explainSentence(
    text,
    request.targetLang,
    {
      onMeaningDelta: (delta) => emit({ type: "meaningDelta", text: delta }),
      onMeaning: (meaning) => emit({ type: "meaning", meaning }),
    },
    signal,
  );
  const match = response.explanation.wordMatch?.trim();
  if (match) {
    try {
      const word = await api.lookUpWord(match, signal);
      if (word.entry?.senses?.length > 0) {
        emit({ type: "word", response: word });
        return;
      }
    } catch {
      if (signal?.aborted) return;
    }
  }
  emit({ type: "sentence", response });
}
