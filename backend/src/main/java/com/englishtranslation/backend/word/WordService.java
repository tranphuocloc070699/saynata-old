package com.englishtranslation.backend.word;

import com.englishtranslation.backend.cache.CacheKeys;
import com.englishtranslation.backend.cache.NotCachedException;
import com.englishtranslation.backend.claude.LlmProperties;
import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.limits.ClaudeGate;
import com.englishtranslation.backend.limits.PrefillContext;
import com.englishtranslation.backend.dictionary.BundledEntryReader;
import com.englishtranslation.backend.dictionary.DictionaryWord;
import com.englishtranslation.backend.dictionary.DictionaryWordRepository;
import com.englishtranslation.backend.media.BackendWordMediaService;
import com.englishtranslation.backend.media.SenseMedia;
import com.englishtranslation.backend.media.SenseMediaReader;
import com.englishtranslation.backend.translation.SentenceSourceAliasRepository;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import tools.jackson.databind.json.JsonMapper;

/** Same cache-first flow as TranslationService, for words missing from the bundled dictionary. */
@Service
public class WordService {

    private static final Logger log = LoggerFactory.getLogger(WordService.class);

    private final WordLookupRepository repository;
    private final ClaudeService claude;
    private final LlmProperties properties;
    private final JsonMapper jsonMapper;

    private final EnglishWords englishWords;
    private final IpaDictionary ipaDictionary;
    private final SimpleWords simpleWords;
    private final BackendWordMediaService mediaService;
    private final SenseMediaReader mediaReader;
    private final DictionaryWordRepository bundled;
    private final BundledEntryReader bundledReader;
    private final ClaudeGate gate;
    private final SentenceSourceAliasRepository aliases;
    private final WordForms forms;

    public WordService(WordLookupRepository repository, ClaudeService claude, LlmProperties properties,
            JsonMapper jsonMapper, EnglishWords englishWords,
            IpaDictionary ipaDictionary, SimpleWords simpleWords,
            BackendWordMediaService mediaService, SenseMediaReader mediaReader,
            DictionaryWordRepository bundled, BundledEntryReader bundledReader, ClaudeGate gate,
            SentenceSourceAliasRepository aliases, WordForms forms) {
        this.aliases = aliases;
        this.forms = forms;
        this.gate = gate;
        this.bundled = bundled;
        this.bundledReader = bundledReader;
        this.mediaService = mediaService;
        this.mediaReader = mediaReader;
        this.simpleWords = simpleWords;
        this.repository = repository;
        this.claude = claude;
        this.properties = properties;
        this.jsonMapper = jsonMapper;
        this.englishWords = englishWords;
        this.ipaDictionary = ipaDictionary;
    }

    public WordResponse lookUp(String word) {
        return lookUp(word, false).response();
    }

    /**
     * With {@code cachedOnly} (TASK-83.4) only the bundled and cached answers are given; a miss throws
     * {@link NotCachedException} before ClaudeGate, so the app can ask while the user types.
     * Every request logs one {@link WordTiming} line with the time of each step.
     */
    public WordAnswer lookUp(String word, boolean cachedOnly) {
        WordTiming timing = new WordTiming();
        try {
            WordAnswer answer = lookUp(word, cachedOnly, timing);
            timing.ok(answer.origin());
            return answer;
        } catch (RuntimeException e) {
            timing.failed(e);
            throw e;
        } finally {
            timing.log();
        }
    }

    private WordAnswer lookUp(String word, boolean cachedOnly, WordTiming timing) {
        String normalized = CacheKeys.normalizeWord(word);
        timing.word(normalized);

        // A bundled word is answered from its own entry. The bundled entry wins (TASK-58): Claude is not
        // called and no word_lookup row is made, so a word is never in both lists.
        Optional<DictionaryWord> bundledWord = timing.time("lookup", () -> bundled.findWithSensesByLemma(normalized));
        if (bundledWord.isPresent()) {
            return new WordAnswer(bundledResponse(normalized, bundledWord.get()), WordAnswer.Origin.BUNDLED);
        }

        // TASK-114.5: the backend (not the client) decides when Claude may describe a phrase or a word that is not on
        // the word list: only when the sentence endpoint returned it as a wordMatch for the current prompt version.
        boolean fromWordMatch = timing.time("lookup",
                () -> aliases.existsWordMatch(normalized, properties.sentencePromptVersion()));

        // A phrase ("give up", "a piece of cake") is answered only from the cache, filled by the local collection
        // (TASK-83.9), unless it is a wordMatch. Otherwise it never calls Claude and is never "not a word": a miss is
        // 404 not_cached, and the app then explains the text as a sentence.
        if (normalized.contains(" ") && !fromWordMatch) {
            return timing.time("lookup", () -> cachedPhrase(normalized));
        }

        // The cache is read before the word list (TASK-83.16): the local collection pushes tech terms such as "vue"
        // that are not on the list, and they must be answered. Claude is still never called for such a word.
        String cacheKey = CacheKeys.key("word", properties.wordPromptVersion(), normalized);

        Optional<WordLookup> saved = timing.time("lookup", () -> repository.findByCacheKey(cacheKey));
        if (saved.isPresent()) {
            return new WordAnswer(response(normalized, readEntry(saved.get()), true, mediaOf(saved.get().getId())),
                    WordAnswer.Origin.CACHED);
        }
        // A form of a bundled or cached word ("ran", "contaminated"): the lemma's entry, and Claude is not called
        // (TASK-118). It is checked after the exact cache, so a word with its own entry ("glasses") keeps it.
        Optional<WordAnswer> asForm = timing.time("lookup", () -> formAnswer(normalized));
        if (asForm.isPresent()) {
            return asForm.get();
        }

        // Not a real word: answer "no senses" (the app shows "not an English word") without calling Claude.
        // Nothing is saved, so a later update of the word list can fix a missing word.
        if (!fromWordMatch && !englishWords.contains(normalized)) {
            log.debug("'{}' is not on the English word list and not cached, Claude not called", normalized);
            return new WordAnswer(new WordResponse(normalized, new WordEntryView(List.of()), false, null),
                    WordAnswer.Origin.NOT_A_WORD);
        }
        if (cachedOnly) {
            throw new NotCachedException();
        }

        // Only a word that is not bundled and not cached gets here. A guest cannot cause a Claude call.
        timing.time("gate", gate::beforeNewCall);
        WordEntry entry = timing.time("llm", () -> claude.describeWord(normalized));
        boolean needsReview = false;
        List<String> problems = simpleWords.problems(entry, normalized);
        if (!problems.isEmpty()) {
            // One retry with feedback, never more. If it still fails, we save it and mark it (TASK-16).
            WordEntry first = entry;
            List<String> firstProblems = problems;
            entry = timing.time("retry", () -> retryWithFeedback(normalized, first, firstProblems));
            problems = simpleWords.problems(entry, normalized);
            needsReview = !problems.isEmpty();
            if (needsReview) {
                timing.needsReview();
                log.warn("'{}' saved with needsReview, still hard after the retry: {}", normalized, problems);
            }
        }
        try {
            WordLookup row = new WordLookup(
                    cacheKey, normalized, jsonMapper.writeValueAsString(entry), properties.model(),
                    properties.wordPromptVersion(), needsReview);
            row.setCefr(entry.firstCefr());
            timing.time("save", () -> repository.saveAndFlush(row));
            startMediaJob(row.getId(), normalized, entry);
            return new WordAnswer(response(normalized, entry, false, Map.of()), WordAnswer.Origin.NEW);
        } catch (DataIntegrityViolationException e) {
            // Another request saved the same key while we waited for Claude. Keep the first answer.
            WordLookup first = repository.findByCacheKey(cacheKey).orElseThrow(() -> e);
            return new WordAnswer(response(normalized, readEntry(first), true, mediaOf(first.getId())),
                    WordAnswer.Origin.CACHED);
        }
    }

    private WordAnswer cachedPhrase(String phrase) {
        String cacheKey = CacheKeys.key("word", properties.wordPromptVersion(), phrase);
        Optional<WordLookup> saved = repository.findByCacheKey(cacheKey);
        if (saved.isPresent()) {
            return new WordAnswer(response(phrase, readEntry(saved.get()), true, mediaOf(saved.get().getId())),
                    WordAnswer.Origin.CACHED);
        }
        // "gave up": the cached entry of "give up" (TASK-118).
        return formAnswer(phrase).orElseThrow(NotCachedException::new);
    }

    /**
     * TASK-118: the entry of the first lemma of this form that has one, with matchedForm ("ran", "past tense").
     * Bundled lemmas are tried first. Empty when the text is not a form, or none of its lemmas has an entry yet:
     * then the old flow goes on (a form is never sent to Claude in place of its lemma).
     */
    private Optional<WordAnswer> formAnswer(String form) {
        for (WordForms.Match match : forms.find(form)) {
            if (match.bundled()) {
                Optional<DictionaryWord> word = bundled.findWithSensesByLemma(match.lemma());
                if (word.isPresent()) {
                    return Optional.of(new WordAnswer(bundledResponse(match.lemma(), word.get())
                            .withMatchedForm(form, match.type()), WordAnswer.Origin.BUNDLED));
                }
            } else {
                String cacheKey = CacheKeys.key("word", properties.wordPromptVersion(), match.lemma());
                Optional<WordLookup> saved = repository.findByCacheKey(cacheKey);
                if (saved.isPresent()) {
                    WordResponse reply = response(match.lemma(), readEntry(saved.get()), true, mediaOf(saved.get().getId()));
                    return Optional.of(new WordAnswer(reply.withMatchedForm(form, match.type()), WordAnswer.Origin.CACHED));
                }
            }
        }
        return Optional.empty();
    }

    /** The reply for a bundled word: its entry and media from Postgres, cached = true (nothing was generated). */
    private WordResponse bundledResponse(String word, DictionaryWord bundledWord) {
        WordEntry entry = bundledReader.read(bundledWord);
        Map<Integer, SenseMedia> media;
        try {
            media = mediaReader.forBundledWords(List.of(bundledWord.getId())).getOrDefault(bundledWord.getId(), Map.of());
        } catch (RuntimeException e) {
            log.warn("Could not read the media of dictionary_word {}: {}", bundledWord.getId(), e.toString());
            media = Map.of();
        }
        String ipa = bundledWord.getIpa() != null ? bundledWord.getIpa() : ipaDictionary.ipaFor(word);
        return new WordResponse(word, WordEntryView.of(entry, media), true, ipa);
    }

    /** Asks Claude once more, naming the problems. If that call fails, we keep the first entry. */
    private WordEntry retryWithFeedback(String word, WordEntry first, List<String> problems) {
        String feedback = "Your last answer used words that are too hard. Write the whole entry again. "
                + "Use only very common words in definitions and in easy examples. Problems: "
                + String.join("; ", problems);
        try {
            gate.checkBudget(); // the second call of the same request: only the money limit is checked again
            return claude.describeWordAgain(word, feedback);
        } catch (RuntimeException e) {
            log.warn("Retry for '{}' failed, keeping the first entry: {}", word, e.toString());
            return first;
        }
    }

    /** Adds the IPA at request time, so rows saved before IPA existed get it too. */
    private WordResponse response(String word, WordEntry entry, boolean cached, Map<Integer, SenseMedia> media) {
        return new WordResponse(word, WordEntryView.of(entry, media), cached, ipaDictionary.ipaFor(word));
    }

    /** The media of a saved word, by sense position. A media problem must never break the word answer. */
    private Map<Integer, SenseMedia> mediaOf(Long lookupId) {
        try {
            return mediaReader.forBackendWords(List.of(lookupId)).getOrDefault(lookupId, Map.of());
        } catch (RuntimeException e) {
            log.warn("Could not read the media of word_lookup {}: {}", lookupId, e.toString());
            return Map.of();
        }
    }

    /**
     * Starts the picture job on its own thread. It is not waited for; the picture shows on the next lookup.
     * A word saved by the prefill job gets no picture (developer, 10-16): no Pixabay call, no claim row, no ffmpeg.
     */
    private void startMediaJob(Long lookupId, String word, WordEntry entry) {
        if (PrefillContext.current().isPresent()) {
            log.debug("'{}' was saved by the prefill job, no picture", word);
            return;
        }
        try {
            mediaService.fetchInBackground(lookupId, word, entry);
        } catch (RuntimeException e) {
            log.warn("Could not start the media job for '{}': {}", word, e.toString());
        }
    }

    private WordEntry readEntry(WordLookup lookup) {
        return jsonMapper.readValue(lookup.getEntryJson(), WordEntry.class);
    }
}
