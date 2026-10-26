package com.englishtranslation.backend.translation;

import com.englishtranslation.backend.cache.CacheKeys;
import com.englishtranslation.backend.cache.NotCachedException;
import com.englishtranslation.backend.claude.ClaudeProperties;
import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.claude.NotEnglishException;
import com.englishtranslation.backend.limits.ClaudeGate;
import com.englishtranslation.backend.lines.LineTranslationService;
import com.englishtranslation.backend.word.EnglishWords;
import java.util.List;
import java.util.Optional;
import java.util.function.BiFunction;
import java.util.function.Consumer;
import java.util.function.Function;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.json.JsonMapper;

/**
 * Cache first: read the DB, and only call Claude on a miss.
 *
 * A sentence answer has two parts (TASK-106.6). The English part (prompt v10) is cached once for all languages: its
 * key has no language. The language line {@code explanation.translation} comes from {@code line_translation}
 * through {@link LineTranslationService}: saved line, else one small line call, else "" (never null: old apps decode a String; a guest, a cachedOnly
 * request, a refused or failed call). For English there is no line call; the translation is the text itself.
 *
 * Text typed in another language (TASK-114.1) is answered by Claude with its English version. The row is saved under
 * the key of that English version, so different wordings with the same English share one row; a small alias row
 * ({@link SentenceSourceAlias}) maps the typed text to it, so the same typed text is a hit next time.
 *
 * There is no @Transactional here on purpose: the Claude call can take seconds, and a
 * transaction would hold a DB connection open the whole time.
 *
 * Every request logs one {@link SentenceTiming} line with the time of each step (TASK-113).
 */
@Service
public class TranslationService {

    /** The source_text column holds 500 characters; a longer English version is answered but not saved. */
    private static final int MAX_SAVED_TEXT = 500;

    private static final TypeReference<List<Explanation.Word>> WORD_LIST = new TypeReference<>() {
    };

    private final SentenceTranslationRepository repository;
    private final SentenceSourceAliasRepository aliases;
    private final ClaudeService claude;
    private final ClaudeProperties properties;
    private final JsonMapper jsonMapper;
    private final PersonalTextDetector personalTextDetector;
    private final ClaudeGate gate;
    private final LineTranslationService lines;
    private final EnglishWords englishWords;

    public TranslationService(SentenceTranslationRepository repository, SentenceSourceAliasRepository aliases,
            ClaudeService claude, ClaudeProperties properties, JsonMapper jsonMapper,
            PersonalTextDetector personalTextDetector, ClaudeGate gate, LineTranslationService lines,
            EnglishWords englishWords) {
        this.englishWords = englishWords;
        this.aliases = aliases;
        this.gate = gate;
        this.lines = lines;
        this.repository = repository;
        this.claude = claude;
        this.properties = properties;
        this.jsonMapper = jsonMapper;
        this.personalTextDetector = personalTextDetector;
    }

    public TranslationResponse translate(String text, TargetLanguage targetLang) {
        return translate(text, targetLang, false);
    }

    /** With {@code cachedOnly} (TASK-83.4) a miss throws {@link NotCachedException} and Claude is never asked. */
    public TranslationResponse translate(String text, TargetLanguage targetLang, boolean cachedOnly) {
        return translate(text, targetLang, cachedOnly, false, (normalized, timing) -> claude.explainSentence(normalized, lineLangFor(targetLang, normalized)));
    }

    /** Same as the four-argument version, for callers that do not want the word-by-word text. */
    public TranslationResponse translateStreaming(String text, TargetLanguage targetLang, Consumer<String> onMeaning) {
        return translateStreaming(text, targetLang, delta -> {
        }, onMeaning);
    }

    /**
     * Same as {@link #translate}, but a Claude call is streamed. While Claude writes the simple English meaning,
     * {@code onMeaningDelta} gets its new characters (about every 50 ms). {@code onMeaning} gets the whole meaning
     * once it is complete, before the words and the translation are done.
     * On a cache hit neither is called. The return value is the same as {@link #translate} gives.
     */
    public TranslationResponse translateStreaming(String text, TargetLanguage targetLang,
            Consumer<String> onMeaningDelta, Consumer<String> onMeaning) {
        return translateStreaming(text, targetLang, false, onMeaningDelta, onMeaning);
    }

    /** The streaming version with {@code cachedOnly}: a miss throws {@link NotCachedException}. */
    public TranslationResponse translateStreaming(String text, TargetLanguage targetLang, boolean cachedOnly,
            Consumer<String> onMeaningDelta, Consumer<String> onMeaning) {
        return translate(text, targetLang, cachedOnly, true, (normalized, timing) -> {
            MeaningStream meaningStream = new MeaningStream(onMeaningDelta, onMeaning);
            return claude.explainSentenceStreaming(normalized, piece -> {
                timing.firstToken();
                meaningStream.feed(piece);
            }, lineLangFor(targetLang, normalized));
        });
    }

    /** The language to ask for in the sentence call itself (TASK-115), or null when no line is needed. */
    private TargetLanguage lineLangFor(TargetLanguage targetLang, String normalized) {
        return lines.wantsLine(targetLang, normalized) ? targetLang : null;
    }

    /** Times the request and logs one line, whatever the result. */
    private TranslationResponse translate(String text, TargetLanguage targetLang, boolean cachedOnly, boolean stream,
            BiFunction<String, SentenceTiming, Explanation> callClaude) {
        SentenceTiming timing = new SentenceTiming(targetLang, stream);
        try {
            TranslationResponse response = translate(text, targetLang, cachedOnly, callClaude, timing);
            timing.ok();
            return response;
        } catch (RuntimeException e) {
            timing.failed(e);
            throw e;
        } finally {
            timing.log();
        }
    }

    /** The cache rules, shared by both ways in. {@code askClaude} runs only when there is no cached answer. */
    private TranslationResponse translate(String text, TargetLanguage targetLang, boolean cachedOnly,
            BiFunction<String, SentenceTiming, Explanation> callClaude, SentenceTiming timing) {
        // Every way to Claude goes through the gate: signed in? budget left? under the user's limit?
        // It runs only here, after the cache lookup failed, so cache hits stay free for everyone.
        // A cachedOnly request stops before the gate: personal text (never cached) and misses get not_cached.
        Function<String, Explanation> askClaude = normalizedText -> {
            if (cachedOnly) {
                timing.cache("not-cached");
                throw new NotCachedException();
            }
            timing.time("gate", gate::beforeNewCall);
            return timing.time("llm", () -> BetterCheck.apply(normalizedText, askOrRetry(normalizedText, callClaude, timing)));
        };
        String normalized = CacheKeys.normalizeSentence(text);

        // Personal text (email, phone, link, long number) is explained, but never saved to
        // or read from the shared cache. Its language line is not saved either.
        if (personalTextDetector.looksPersonal(normalized)) {
            timing.cache("personal");
            Explanation explanation = askClaude.apply(normalized);
            return new TranslationResponse(normalized, targetLang,
                    withLanguageLine(explanation, targetLang, normalized, cachedOnly, false, true, timing), false);
        }

        String version = properties.sentencePromptVersion();
        String cacheKey = CacheKeys.sentenceKey(version, normalized);
        timing.key(cacheKey);

        Optional<SentenceTranslation> saved = timing.time("lookup", () -> repository.findByCacheKey(cacheKey));
        if (saved.isPresent()) {
            timing.cache("hit");
            return answer(normalized, targetLang, readExplanation(saved.get()), true, cachedOnly, timing);
        }

        // Text typed in another language was saved under the key of its English version (TASK-114.1). The alias finds it.
        Optional<TranslationResponse> viaAlias = timing.time("lookup",
                () -> readByAlias(version, normalized, targetLang, cachedOnly, timing));
        if (viaAlias.isPresent()) {
            return viaAlias.get();
        }

        // Exact text missed. Try the loose key: "how are you" finds a saved "How are you?".
        // The exact key was tried first, so "US" and "us" stay apart when both are saved.
        if (!CacheKeys.normalizeSentenceLoose(normalized).isEmpty()) {
            String matchKey = CacheKeys.sentenceMatchKey(version, normalized);
            Optional<SentenceTranslation> similar = timing.time("lookup",
                    () -> repository.findFirstByMatchKeyOrderByCreatedAtAscIdAsc(matchKey));
            if (similar.isPresent()) {
                timing.cache("loose-hit");
                // The text in the answer is what the user typed; the explanation is the saved one.
                return answer(normalized, targetLang, readExplanation(similar.get()), true, cachedOnly, timing);
            }
        }

        timing.cache("miss");
        Explanation explanation = askClaude.apply(normalized);
        if (explanation.english() != null) {
            return saveOtherLanguage(normalized, targetLang, explanation, version, cachedOnly, timing);
        }
        try {
            // The row has no language: "en" is the language of the explanation, and the translation column stays empty.
            timing.time("save", () -> repository.saveAndFlush(new SentenceTranslation(
                    cacheKey, normalized, "en", explanation.meaning(),
                    jsonMapper.writeValueAsString(explanation.words()), explanation.better(),
                    explanation.betterWhy(), "", properties.model(), version)));
            return answer(normalized, targetLang, explanation, false, cachedOnly, timing);
        } catch (DataIntegrityViolationException e) {
            // Another request saved the same key while we waited for Claude. Keep the first answer.
            SentenceTranslation first = repository.findByCacheKey(cacheKey).orElseThrow(() -> e);
            return answer(normalized, targetLang, readExplanation(first), true, cachedOnly, timing);
        }
    }

    /**
     * The model sometimes calls a rare-but-real phrase "none" (random letters). The word list is the judge of what
     * a word is, so when every word is on it, the text is asked once more with a note, and only a second "none" is a 422.
     */
    private Explanation askOrRetry(String normalizedText, BiFunction<String, SentenceTiming, Explanation> callClaude,
            SentenceTiming timing) {
        try {
            return callClaude.apply(normalizedText, timing);
        } catch (NotEnglishException e) {
            if (!NotEnglishException.NOT_A_WORD_CODE.equals(e.code()) || !englishWords.containsOnlyWords(normalizedText)) {
                throw e;
            }
            return claude.explainSentenceOfRealWords(normalizedText);
        }
    }

    /** A saved alias of the typed text: its English row with the typed text's own language and word match. */
    private Optional<TranslationResponse> readByAlias(String version, String normalized, TargetLanguage targetLang,
            boolean cachedOnly, SentenceTiming timing) {
        Optional<SentenceSourceAlias> alias = aliases.findById(CacheKeys.sentenceSourceKey(version, normalized));
        if (alias.isEmpty()) {
            return Optional.empty();
        }
        Optional<SentenceTranslation> row = repository.findByCacheKey(alias.get().getCacheKey());
        if (row.isEmpty()) {
            return Optional.empty();
        }
        timing.cache("hit");
        Explanation english = otherLanguage(readExplanation(row.get()), row.get().getSourceText(), alias.get());
        return Optional.of(answer(normalized, targetLang, english, true, cachedOnly, timing));
    }

    /**
     * Claude answered for text in another language (TASK-114.1). The English part is saved under the key of the
     * English version, so another wording with the same English finds the same row and no second row is made. An
     * alias row remembers the typed text, with its language and word match, for the next request.
     */
    private TranslationResponse saveOtherLanguage(String normalized, TargetLanguage targetLang, Explanation explanation,
            String version, boolean cachedOnly, SentenceTiming timing) {
        String english = CacheKeys.normalizeSentence(explanation.english());
        if (english.length() > MAX_SAVED_TEXT) {
            return answer(normalized, targetLang, explanation, false, cachedOnly, timing);
        }
        String englishKey = CacheKeys.sentenceKey(version, english);
        Explanation shown = explanation;
        Optional<SentenceTranslation> existing = timing.time("lookup", () -> repository.findByCacheKey(englishKey));
        if (existing.isPresent()) {
            shown = withSavedEnglishPart(explanation, existing.get());
        } else {
            try {
                timing.time("save", () -> repository.saveAndFlush(new SentenceTranslation(
                        englishKey, english, "en", explanation.meaning(),
                        jsonMapper.writeValueAsString(explanation.words()), null, null, "", properties.model(),
                        version)));
            } catch (DataIntegrityViolationException e) {
                // Another request saved the same English version while we waited for Claude. Keep the first answer.
                SentenceTranslation first = repository.findByCacheKey(englishKey).orElseThrow(() -> e);
                shown = withSavedEnglishPart(explanation, first);
            }
        }
        saveAlias(CacheKeys.sentenceSourceKey(version, normalized), englishKey, explanation);
        return answer(normalized, targetLang, shown, false, cachedOnly, timing);
    }

    private Explanation withSavedEnglishPart(Explanation fromClaude, SentenceTranslation row) {
        Explanation saved = readExplanation(row);
        return new Explanation(row.getSourceText(), fromClaude.sourceLang(), fromClaude.wordMatch(), saved.meaning(),
                saved.words(), saved.better(), saved.betterWhy(), fromClaude.translation());
    }

    private void saveAlias(String aliasKey, String cacheKey, Explanation explanation) {
        try {
            aliases.saveAndFlush(new SentenceSourceAlias(aliasKey, cacheKey, explanation.sourceLang(),
                    explanation.wordMatch()));
        } catch (DataIntegrityViolationException e) {
            // The same typed text was saved by another request at the same time. The first alias is as good.
        }
    }

    /** The saved English explanation of a row, with the English version, the language and the word match on top. */
    private static Explanation otherLanguage(Explanation saved, String english, SentenceSourceAlias alias) {
        String match = alias.getWordMatch().isEmpty() ? null : alias.getWordMatch();
        return new Explanation(english, alias.getSourceLang(), match, saved.meaning(), saved.words(), saved.better(),
                saved.betterWhy(), "");
    }

    /** The English part is ready (cached or new): add the language line. */
    private TranslationResponse answer(String normalized, TargetLanguage targetLang, Explanation english, boolean cached,
            boolean cachedOnly, SentenceTiming timing) {
        // A new English part means this request already passed the gate; the line call then skips the user limit.
        return new TranslationResponse(normalized, targetLang,
                withLanguageLine(english, targetLang, normalized, cachedOnly, true, !cached, timing), cached);
    }

    private Explanation withLanguageLine(Explanation english, TargetLanguage targetLang, String normalized,
            boolean cachedOnly, boolean store, boolean alreadyGated, SentenceTiming timing) {
        // "line" is the saved-line lookup plus, on a miss, the second LLM call. The line is built from the typed text.
        // English needs no line: it is the text itself, or the English version when the text was another language.
        // A learner who typed in the target language needs no line either: the typed text is the line.
        String line;
        if (targetLang == TargetLanguage.EN) {
            line = english.english() != null ? english.english() : normalized;
        } else if (targetLang.code().equals(english.sourceLang())) {
            line = normalized;
        } else if (english.translation() != null && !english.translation().isBlank()) {
            // The sentence call wrote the line too (TASK-115): no second call.
            line = lines.keepLine(targetLang, normalized, english.translation().strip(), store);
        } else {
            line = timing.time("line", () -> lines.lineFor(targetLang, normalized, cachedOnly, store, alreadyGated))
                    .orElse("");
        }
        return english.withTranslation(line);
    }

    private Explanation readExplanation(SentenceTranslation row) {
        List<Explanation.Word> words = jsonMapper.readValue(row.getWordsJson(), WORD_LIST);
        return new Explanation(row.getMeaning(), words, row.getBetter(), row.getBetterWhy(), "");
    }
}
