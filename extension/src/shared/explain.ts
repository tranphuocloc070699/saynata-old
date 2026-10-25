/** One explanation from start to end: word or sentence, then the events for the card. Used by the service worker. */
import { ApiError, MESSAGES, type SaynataApi } from "./api";
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
        try {
          emit({ type: "word", response: await api.lookUpWord(text.word, signal) });
        } catch (error) {
          // A single non-English word ("buồn") is not in the word API: the sentence API finds the English word.
          if (signal?.aborted || !(error instanceof ApiError) || (error.status !== 404 && error.status !== 422)) throw error;
          try {
            await explainSentence(api, request, cleanSelection(request.text), emit, signal);
          } catch {
            throw error; // keep the word error: the sentence call said nothing better
          }
        }
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
