"use client";
/**
 * The homepage tool (TASK-102.1). The query lives in the address (/?q=...), so a result can be shared, reloaded
 * and reached with Back. The search itself is in lib/explain.ts; this file holds the state and the motion.
 */
import { useEffect, useEffectEvent, useRef, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { SaynataApi, type Suggestion } from "@/lib/api";
import { browserTokens } from "@/lib/auth";
import { fetchResult, fetchTranslation, startState, type Result } from "@/lib/explain";
import { ENTER, gsap, useGSAP, withMotion } from "@/lib/motion";
import { settingsStore } from "@/lib/settings";
import { liveItems } from "@/lib/sync";
import { useSync } from "@/lib/useSync";
import { useTargetLanguage } from "@/lib/targetLanguage";
import { Alert } from "../icons";
import type { CatMood } from "../PixelCat";
import { Composer } from "./Composer";
import { SentenceCard } from "./SentenceCard";
import { WordCard, WordSkeleton } from "./WordCard";
import { WordSheet } from "./WordSheet";

const api = new SaynataApi("", browserTokens);
const SUGGEST_DELAY_MS = 250;
const SUGGEST_MAX_LENGTH = 40;
/** Cached answers, so a guest can try them (TASK-83.11 prefill). */
const SAMPLES = ["give up", "run", "Hold on a second.", "Looks good."];
/** A signed-in learner's empty box offers their latest lookups instead. */
const RECENT_CHIPS = 10;
/** How long the box stays empty before the shown result is removed. */
const RESET_DELAY_MS = 400;

export function Home() {
  const router = useRouter();
  const pathname = usePathname();
  const query = useSearchParams().get("q")?.trim() ?? "";
  const [targetLang] = useTargetLanguage();
  // The account's settings load once; a language picked here goes to the account too.
  useEffect(() => void settingsStore.load(), []);
  /** Bumped by a submit of the same text, so "try again" runs the search again. */
  const [attempt, setAttempt] = useState(0);
  /** A word tapped in the sentence result, shown in the sheet over it; the search itself does not change. */
  const [sheetWord, setSheetWord] = useState<string | null>(null);

  const [text, setText] = useState(query);
  const [result, setResult] = useState<Result>(() => startState(query));
  const [suggested, setSuggested] = useState<{ prefix: string; list: Suggestion[] }>({ prefix: "", list: [] });
  const root = useRef<HTMLDivElement>(null);

  // A new search (address or retry): show its first state now, during render, not in an effect. A language
  // change is not a new search: the result stays and only its language row loads again (below).
  const runKey = `${query}|${attempt}`;
  const [shownKey, setShownKey] = useState(runKey);
  const [shownQuery, setShownQuery] = useState(query);
  if (shownKey !== runKey) {
    setShownKey(runKey);
    setResult(startState(query));
    if (shownQuery !== query) {
      setShownQuery(query);
      setText(query);
    }
  }

  // A finished lookup goes to History (shown at once, sent in a batch; TASK-102.6). A guest has no store.
  const { store: syncStore, state: syncState } = useSync();
  const recorded = useRef<Result | null>(null);
  useEffect(() => {
    if (!syncStore || recorded.current === result) return;
    if (result.kind === "word") {
      recorded.current = result;
      const sense = result.word.entry.senses[0];
      syncStore.recordLookup("word", result.word.word, sense?.simpleDefinition ?? "", sense ? `${sense.pos} · ${sense.cefr}` : null);
    } else if (result.kind === "sentence" && result.explanation) {
      recorded.current = result;
      syncStore.recordLookup("sentence", result.query, result.explanation.meaning, null);
    }
  }, [result, syncStore]);

  // ...and fetch it. Every state from here on comes from a network callback.
  // The language is read when the search starts, so changing it does not start the search again.
  const startSearch = useEffectEvent((signal: AbortSignal) => fetchResult(api, query, targetLang, setResult, signal));
  useEffect(() => {
    const controller = new AbortController();
    void startSearch(controller.signal);
    return () => controller.abort();
  }, [query, attempt]);

  // A sentence shown in another language: fetch only its language line. A word's row loads by itself (WordCard).
  const lineQuery =
    result.kind === "sentence" && result.explanation && result.lang !== targetLang && targetLang !== "en"
      ? result.query
      : null;
  useEffect(() => {
    if (lineQuery === null) return;
    const controller = new AbortController();
    void fetchTranslation(api, lineQuery, targetLang, controller.signal).then((translation) => {
      if (controller.signal.aborted) return;
      setResult((current) =>
        current.kind === "sentence" && current.query === lineQuery && current.explanation
          ? { ...current, lang: targetLang, explanation: { ...current.explanation, translation } }
          : current,
      );
    });
    return () => controller.abort();
  }, [lineQuery, targetLang]);

  const submit = (value: string) => {
    const clean = value.trim();
    setText(clean);
    if (clean === query) setAttempt((n) => n + 1);
    else router.push(`${pathname}?q=${encodeURIComponent(clean)}`, { scroll: false });
  };

  // The box was emptied: after a short pause remove the result and go back to the start page.
  const emptied = text.trim() === "" && query !== "";
  useEffect(() => {
    if (!emptied) return;
    const timer = setTimeout(() => router.push(pathname, { scroll: false }), RESET_DELAY_MS);
    return () => clearTimeout(timer);
  }, [emptied, pathname, router]);

  // Suggestions while typing: only from the bundle and the cache, so they cost nothing (GET /api/suggest).
  const prefix = text.trim();
  const wantsSuggestions = prefix.length > 0 && prefix.length <= SUGGEST_MAX_LENGTH && prefix !== query;
  useEffect(() => {
    if (!wantsSuggestions) return;
    const controller = new AbortController();
    const timer = setTimeout(() => {
      api
        .suggest(prefix, targetLang, controller.signal)
        .then((list) => setSuggested({ prefix, list }))
        .catch(() => undefined);
    }, SUGGEST_DELAY_MS);
    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [prefix, targetLang, wantsSuggestions]);
  const suggestions =
    wantsSuggestions && suggested.prefix === prefix
      ? suggested.list.filter((s) => s.text.toLowerCase() !== prefix.toLowerCase())
      : [];

  // Motion 1: the page enters (the intro in page.tsx too, so the whole document is searched) and the send
  // button pops in. Runs once. The cat drops onto the card by itself when its picture is ready (MochiCat).
  useGSAP(
    () => {
      withMotion(() => {
        gsap
          .timeline({ defaults: { ease: "power3.out" } })
          .fromTo(gsap.utils.toArray("[data-enter]", document), { opacity: 0, y: 18 }, { opacity: 1, y: 0, duration: 0.6, stagger: 0.08 })
          .from(".send", { scale: 0.6, opacity: 0, duration: 0.4, ease: "back.out(2)" }, 0.45);
      });
    },
    { scope: root },
  );

  // Motion 2: new parts of a result rise in, one after another. Parts already shown are left alone, so the
  // stream finishing (the words and the language row appear) does not replay the card.
  useGSAP(
    () => {
      const fresh = gsap.utils.toArray<HTMLElement>("[data-reveal]:not([data-shown])");
      fresh.forEach((el) => el.setAttribute("data-shown", ""));
      if (fresh.length === 0) return;
      withMotion(() => {
        gsap.from(fresh, { autoAlpha: 0, y: ENTER.y, duration: ENTER.duration, ease: ENTER.ease, stagger: ENTER.stagger });
      });
    },
    { scope: root, dependencies: [result] },
  );

  const recent = liveItems(syncState.history)
    .slice(0, RECENT_CHIPS)
    .map((item) => item.text);
  const startChips = recent.length > 0 ? recent : SAMPLES;
  const chips = suggestions.length > 0 ? suggestions.map((s) => s.text) : result.kind === "idle" && !text ? startChips : [];

  // Motion 3: suggestions and sample chips fan out quickly when the list changes.
  useGSAP(
    () => {
      withMotion(() => {
        gsap.from(".chip-item", { autoAlpha: 0, y: 6, duration: 0.25, ease: "power1.out", stagger: 0.03 });
      });
    },
    { scope: root, dependencies: [chips.join("\n")], revertOnUpdate: true },
  );

  const mood: CatMood =
    result.kind === "loading" || (result.kind === "sentence" && !result.explanation)
      ? "busy"
      : text.length > 0 || result.kind !== "idle"
        ? "awake"
        : "asleep";

  return (
    // One centered column: the composer on top, the result below. A fold opens by pushing the page down,
    // so the result never gets its own scrollbar.
    <div ref={root} className="mx-auto flex w-full max-w-[680px] flex-col gap-5">
      <div className="flex flex-col gap-5">
        <Composer
          value={text}
          onChange={setText}
          onSubmit={() => submit(text)}
          targetLang={targetLang}
          onLanguage={(code) => settingsStore.update({ targetLanguage: code })}
          mood={mood}
        />

        {chips.length > 0 && (
          <ul aria-label={suggestions.length > 0 ? "Suggestions" : recent.length > 0 ? "Recent" : "Try one"} className="-mt-1 flex flex-wrap justify-center gap-2">
            {chips.map((chip) => (
              <li key={chip} className="chip-item">
                <button
                  type="button"
                  onClick={() => submit(chip)}
                  className="min-h-9 cursor-pointer rounded-full border border-hairline bg-surface px-3.5 text-sm text-ink-2 transition-colors hover:border-accent/50 hover:text-accent"
                >
                  {chip}
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>

      <div className="flex flex-col gap-5">
        <div aria-live="polite">
          {result.kind === "loading" && <WordSkeleton />}
          {result.kind === "error" && (
            <p data-reveal key={result.message} role="alert" className="flex items-start gap-2 px-2 text-error">
              <Alert className="mt-0.5 size-4 shrink-0" />
              <span>{result.message}</span>
            </p>
          )}
        </div>
        {result.kind === "word" && <WordCard key={result.query} word={result.word} targetLang={targetLang} />}
        {result.kind === "sentence" && (
          <SentenceCard
            key={result.query}
            text={result.query}
            meaning={result.meaning}
            explanation={result.explanation}
            targetLang={targetLang}
            translating={lineQuery !== null}
            onWord={setSheetWord}
          />
        )}
      </div>
      <WordSheet word={sheetWord} targetLang={targetLang} onClose={() => setSheetWord(null)} />
    </div>
  );
}
