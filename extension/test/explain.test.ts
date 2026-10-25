import { describe, expect, it } from "vitest";
import { SaynataApi } from "../src/shared/api";
import { explain } from "../src/shared/explain";
import type { ExplainEvent } from "../src/shared/messages";
import { event, fakeFetch, json, sentenceResponse, sse, wordResponse } from "./helpers";

async function run(text: string, ...handlers: Parameters<typeof fakeFetch>) {
  const { fetchImpl, calls } = fakeFetch(...handlers);
  const events: ExplainEvent[] = [];
  await explain(new SaynataApi("https://api.test", undefined, fetchImpl), { text, targetLang: "vi" }, (e) => events.push(e));
  return { events, calls };
}

describe("explain", () => {
  it("one word goes to the word API", async () => {
    const { events, calls } = await run("Reluctant.", () => json(wordResponse));
    expect(calls[0].url).toBe("https://api.test/api/words/reluctant");
    expect(events).toEqual([{ type: "word", response: wordResponse }]);
  });

  it("more than one word goes to the stream, with the meaning before the result", async () => {
    const { events } = await run(
      "reluctant to approve the plan",
      () => sse(event("meaning-delta", { text: "Not" }), event("meaning", { meaning: "Not wanting." }), event("done", sentenceResponse)),
    );
    expect(events.map((e) => e.type)).toEqual(["meaningDelta", "meaning", "sentence"]);
  });

  it("errors become one error event", async () => {
    const { events } = await run("zyzzyva", () => json({ status: 401, code: "sign_in_required" }, 401));
    expect(events).toEqual([{ type: "error", kind: "signInRequired", message: "Sign in to get a new explanation." }]);
  });

  it("refuses empty and long text without a request", async () => {
    expect((await run("   ")).events).toEqual([{ type: "error", kind: "empty", message: "Select some English text first." }]);
    const long = await run("word ".repeat(120));
    expect(long.events[0]).toMatchObject({ kind: "tooLong", message: "Select up to 500 characters." });
    expect(long.calls).toHaveLength(0);
  });
});

describe("explain: non-English input (TASK-114.4)", () => {
  const vietnamese = {
    ...sentenceResponse,
    text: "tôi thấy buồn hôm nay",
    explanation: { ...sentenceResponse.explanation, english: "I feel sad today.", sourceLang: "vi" },
  };
  const japanese = {
    ...sentenceResponse,
    text: "今日は悲しいです",
    explanation: { ...sentenceResponse.explanation, english: "I am sad today.", sourceLang: "ja" },
  };
  const withMatch = { ...vietnamese, explanation: { ...vietnamese.explanation, wordMatch: "sad" } };

  it("a Vietnamese sentence keeps english and sourceLang in the sentence result", async () => {
    const { events } = await run("tôi thấy buồn hôm nay", () => sse(event("done", vietnamese)));
    expect(events).toEqual([{ type: "sentence", response: vietnamese }]);
  });

  it("a Japanese sentence works the same", async () => {
    const { events } = await run(
      "今日は悲しいです", // no spaces: it counts as one word, so the word API says no first
      () => json({ status: 404, code: "not_found" }, 404),
      () => sse(event("done", japanese)),
    );
    expect(events).toEqual([{ type: "sentence", response: japanese }]);
  });

  it("English input has no english field and still ends as a sentence", async () => {
    const { events } = await run("reluctant to approve the plan", () => sse(event("done", sentenceResponse)));
    expect(events).toEqual([{ type: "sentence", response: sentenceResponse }]);
    expect(sentenceResponse.explanation).not.toHaveProperty("english");
  });

  it("a wordMatch opens the word card", async () => {
    const { events, calls } = await run("buồn bã", () => sse(event("done", withMatch)), () => json(wordResponse));
    expect(calls[1].url).toBe("https://api.test/api/words/sad");
    expect(events).toEqual([{ type: "word", response: wordResponse }]);
  });

  it("a failed wordMatch lookup falls back to the sentence result", async () => {
    const { events } = await run("buồn bã", () => sse(event("done", withMatch)), () => json({ status: 404, code: "not_cached" }, 404));
    expect(events).toEqual([{ type: "sentence", response: withMatch }]);
  });

  it("a wordMatch with no senses falls back to the sentence result", async () => {
    const empty = { ...wordResponse, entry: { senses: [] } };
    const { events } = await run("buồn bã", () => sse(event("done", withMatch)), () => json(empty));
    expect(events).toEqual([{ type: "sentence", response: withMatch }]);
  });

  it("a single Vietnamese word refused by the word API goes to the sentence API, then the word card", async () => {
    const { events, calls } = await run(
      "buồn",
      () => json({ status: 404, code: "not_found" }, 404),
      () => sse(event("done", withMatch)),
      () => json(wordResponse),
    );
    expect(calls.map((c) => c.url)).toEqual([
      "https://api.test/api/words/bu%E1%BB%93n",
      "https://api.test/api/translations/stream",
      "https://api.test/api/words/sad",
    ]);
    expect(events).toEqual([{ type: "word", response: wordResponse }]);
  });

  it("a refused word keeps its own error when the sentence call fails too", async () => {
    const { events } = await run("zyzzyva", () => json({ status: 404, code: "not_found" }, 404), () => json({ status: 422, code: "not_english" }, 422));
    expect(events).toHaveLength(1);
    expect(events[0]).toMatchObject({ type: "error" });
  });

  describe("a word with no senses or a refused word (TASK-114 follow-up)", () => {
    const noSenses = { ...wordResponse, entry: { ...wordResponse.entry, senses: [] } };

    it("a 200 without senses goes to the sentence API, then the word card of the wordMatch", async () => {
      const { events, calls } = await run(
        "buồn",
        () => json(noSenses),
        () => sse(event("done", withMatch)),
        () => json(wordResponse),
      );
      expect(calls.map((c) => c.url)).toEqual([
        "https://api.test/api/words/bu%E1%BB%93n",
        "https://api.test/api/translations/stream",
        "https://api.test/api/words/sad",
      ]);
      expect(events).toEqual([{ type: "word", response: wordResponse }]);
    });

    it("a 422 from the word API goes to the sentence API too", async () => {
      const { events } = await run("食べる", () => json({ status: 422 }, 422), () => sse(event("done", japanese)));
      expect(events).toEqual([{ type: "sentence", response: japanese }]);
    });

    it("keeps the empty word answer when the sentence call fails", async () => {
      const { events } = await run("teh", () => json(noSenses), () => json({ status: 502 }, 502));
      expect(events).toEqual([{ type: "word", response: noSenses }]);
    });

    it("keeps the word error when the sentence call fails after a 404", async () => {
      const { events } = await run("zyzzyva", () => json({ status: 404, code: "not_found" }, 404), () => json({ status: 502 }, 502));
      expect(events).toHaveLength(1);
      expect(events[0]).toMatchObject({ type: "error", kind: "badRequest" });
    });

    it.each(["not_a_word", "a_name"])("shows the sentence 422 text for %s", async (code) => {
      const { events } = await run(
        "asdkj",
        () => json(noSenses),
        () => json({ status: 422, code, detail: "Server text." }, 422),
      );
      expect(events).toEqual([{ type: "error", kind: "notEnglish", message: "Server text." }]);
    });

    it("does not call the sentence API for a word with senses", async () => {
      const { calls } = await run("Reluctant.", () => json(wordResponse));
      expect(calls).toHaveLength(1);
    });
  });
});
