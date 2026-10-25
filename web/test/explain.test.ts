import { describe, expect, it } from "vitest";
import { ApiError, type TranslationResponse, type WordResponse } from "../src/lib/api";
import { fetchResult, SIGN_IN_MESSAGE, startState, type Result } from "../src/lib/explain";
import { sentenceResponse as sentenceJson, wordResponse as wordJson } from "./helpers";

const wordResponse = () => structuredClone(wordJson) as WordResponse;
const sentenceResponse = () => structuredClone(sentenceJson) as TranslationResponse;

/** Runs fetchResult against a fake api and returns every state it reported, applied in order. */
async function states(api: Parameters<typeof fetchResult>[0], raw: string, controller = new AbortController()) {
  let current: Result = startState(raw);
  const seen: Result[] = [];
  await fetchResult(api, raw, "vi", (next) => seen.push((current = next(current))), controller.signal);
  return seen;
}

const never = () => Promise.reject(new Error("not called"));

describe("startState", () => {
  it("is idle for empty text, loading for a word, an empty sentence card for a sentence", () => {
    expect(startState("  ")).toEqual({ kind: "idle" });
    expect(startState("Run.")).toEqual({ kind: "loading", query: "Run." });
    expect(startState("hold  the door")).toEqual({ kind: "sentence", query: "hold the door", meaning: null, explanation: null });
  });

  it("asks for shorter text over 500 characters", () => {
    expect(startState("a ".repeat(300)).kind).toBe("error");
  });
});

describe("fetchResult", () => {
  it("looks up one word and shows the word card", async () => {
    const word = wordResponse();
    const seen = await states({ lookUpWord: async () => word, explainSentence: never }, "Run.");
    expect(seen).toEqual([{ kind: "word", query: "Run.", word }]);
  });

  it("grows the meaning with each piece, then shows the full answer", async () => {
    const response = sentenceResponse();
    const seen = await states(
      {
        lookUpWord: never,
        explainSentence: async (_text, _lang, handlers) => {
          handlers?.onMeaningDelta?.("Please ");
          handlers?.onMeaningDelta?.("wait.");
          return response;
        },
      },
      "Hold on a second",
    );
    expect(seen.map((s) => (s.kind === "sentence" ? s.meaning : null))).toEqual([
      "Please ",
      "Please wait.",
      response.explanation.meaning,
    ]);
    expect(seen.at(-1)).toMatchObject({ kind: "sentence", explanation: response.explanation });
  });

  it("explains sign-in for a guest's miss", async () => {
    const seen = await states(
      { lookUpWord: never, explainSentence: () => Promise.reject(new ApiError("signInRequired", "x", 401)) },
      "A brand new sentence",
    );
    expect(seen).toEqual([{ kind: "error", query: "A brand new sentence", message: SIGN_IN_MESSAGE }]);
  });

  it("reports nothing after a cancel", async () => {
    const controller = new AbortController();
    const seen = await states(
      {
        lookUpWord: async () => {
          controller.abort();
          return wordResponse();
        },
        explainSentence: never,
      },
      "run",
      controller,
    );
    expect(seen).toEqual([]);
  });
});

describe("fetchResult with non-English input (TASK-114)", () => {
  const withExtra = (extra: object) => {
    const response = sentenceResponse();
    Object.assign(response.explanation, extra);
    return response;
  };

  it("keeps english and sourceLang for Vietnamese and Japanese input", async () => {
    for (const [raw, lang] of [
      ["tôi rất vui khi gặp bạn", "vi"],
      ["お会いできて 嬉しいです", "ja"],
    ]) {
      const response = withExtra({ english: "I am glad to meet you.", sourceLang: lang });
      const seen = await states({ lookUpWord: never, explainSentence: async () => response }, raw);
      expect(seen.at(-1)).toMatchObject({
        kind: "sentence",
        explanation: { english: "I am glad to meet you.", sourceLang: lang },
      });
    }
  });

  it("leaves English input without the new fields", async () => {
    const response = sentenceResponse();
    const seen = await states({ lookUpWord: never, explainSentence: async () => response }, "Hold on a second");
    const last = seen.at(-1) as Extract<Result, { kind: "sentence" }>;
    expect(last.explanation?.english).toBeUndefined();
    expect(last.explanation?.wordMatch).toBeUndefined();
  });

  it("opens the word card for a wordMatch", async () => {
    const word = wordResponse();
    const response = withExtra({ english: "give up", sourceLang: "vi", wordMatch: "give up" });
    const lookups: string[] = [];
    const seen = await states(
      {
        lookUpWord: async (w) => (lookups.push(w), word),
        explainSentence: async () => response,
      },
      "từ bỏ",
    );
    expect(lookups).toEqual(["give up"]);
    expect(seen.at(-1)).toEqual({ kind: "word", query: "từ bỏ", word });
  });

  it("falls back to the sentence result when the word lookup fails or is empty", async () => {
    const response = withExtra({ english: "give up", sourceLang: "vi", wordMatch: "give up" });
    const failing = await states(
      {
        lookUpWord: () => Promise.reject(new ApiError("badRequest", "not cached", 404)),
        explainSentence: async () => response,
      },
      "từ bỏ",
    );
    expect(failing.at(-1)).toMatchObject({ kind: "sentence", explanation: { english: "give up" } });

    const empty = { ...wordResponse(), entry: { senses: [] } } as WordResponse;
    const emptied = await states({ lookUpWord: async () => empty, explainSentence: async () => response }, "từ bỏ");
    expect(emptied.at(-1)).toMatchObject({ kind: "sentence" });
  });

  describe("a word the word API cannot answer", () => {
    const empty = () => ({ ...wordResponse(), entry: { senses: [] } }) as unknown as WordResponse;
    const wordFails = (status: number) => () => Promise.reject(new ApiError("badRequest", "no word", status));

    it("goes to the sentence API and opens the word card of the wordMatch (buồn gives sad)", async () => {
      const sad = wordResponse();
      const lookups: string[] = [];
      const seen = await states(
        {
          lookUpWord: async (w) => (lookups.push(w), lookups.length === 1 ? empty() : sad),
          explainSentence: async () => withExtra({ english: "sad", sourceLang: "vi", wordMatch: "sad" }),
        },
        "buồn",
      );
      expect(lookups).toEqual(["buồn", "sad"]);
      expect(seen[0]).toEqual({ kind: "sentence", query: "buồn", meaning: null, explanation: null });
      expect(seen.at(-1)).toEqual({ kind: "word", query: "buồn", word: sad });
    });

    it("shows the sentence result for a Japanese word with no match (404)", async () => {
      const response = withExtra({ english: "to eat", sourceLang: "ja", wordMatch: "" });
      const seen = await states({ lookUpWord: wordFails(404), explainSentence: async () => response }, "食べる");
      expect(seen.at(-1)).toMatchObject({ kind: "sentence", explanation: { english: "to eat", sourceLang: "ja" } });
    });

    it("also falls back after a 422 from the word API", async () => {
      const response = withExtra({ english: "to eat", sourceLang: "ja" });
      const seen = await states({ lookUpWord: wordFails(422), explainSentence: async () => response }, "食べる");
      expect(seen.at(-1)).toMatchObject({ kind: "sentence" });
    });

    it("keeps the word error when the sentence call fails too", async () => {
      const seen = await states(
        { lookUpWord: wordFails(404), explainSentence: () => Promise.reject(new ApiError("server", "down", 502)) },
        "buồn",
      );
      expect(seen.at(-1)).toEqual({
        kind: "error",
        query: "buồn",
        message: "This word is not in the dictionary yet. Check the spelling.",
      });
    });

    it("keeps the empty word answer when the sentence call fails (sign-in is not shown)", async () => {
      const answer = empty();
      const seen = await states(
        { lookUpWord: async () => answer, explainSentence: () => Promise.reject(new ApiError("signInRequired", "x", 401)) },
        "teh",
      );
      expect(seen.at(-1)).toEqual({ kind: "word", query: "teh", word: answer });
    });

    it.each([
      ["not_a_word", "This does not look like a word or a sentence. Check the spelling."],
      ["a_name", "This looks like a person's name, so there is nothing to explain."],
    ])("shows the sentence 422 message for %s", async (code, message) => {
      const seen = await states(
        { lookUpWord: async () => empty(), explainSentence: () => Promise.reject(new ApiError("notEnglish", message, 422, code)) },
        "asdkj",
      );
      expect(seen.at(-1)).toEqual({ kind: "error", query: "asdkj", message });
    });

    it("does not call the sentence API for an English word with senses", async () => {
      const seen = await states({ lookUpWord: async () => wordResponse(), explainSentence: never }, "run");
      expect(seen.at(-1)).toMatchObject({ kind: "word" });
    });

    it("reports nothing more after an abort during the sentence call", async () => {
      const controller = new AbortController();
      const seen = await states(
        {
          lookUpWord: async () => empty(),
          explainSentence: async () => {
            controller.abort();
            throw new ApiError("server", "aborted", 502);
          },
        },
        "buồn",
        controller,
      );
      expect(seen.at(-1)).toMatchObject({ kind: "sentence", meaning: null });
    });
  });
});
