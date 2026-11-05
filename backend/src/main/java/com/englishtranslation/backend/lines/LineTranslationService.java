package com.englishtranslation.backend.lines;

import com.englishtranslation.backend.cache.CacheKeys;
import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.claude.WordLineAnswer;
import com.englishtranslation.backend.claude.WordLinesAnswer;
import com.englishtranslation.backend.common.ApiException;
import com.englishtranslation.backend.limits.ClaudeGate;
import com.englishtranslation.backend.translation.TargetLanguage;
import java.time.Clock;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.function.BiConsumer;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Language lines: cache first (table line_translation), then ONE Claude call for all misses of a request.
 * The call goes through {@link ClaudeGate}, so a guest, the rate limit and the daily budget are checked as for
 * every other new Claude call. A cachedOnly request never reaches the gate.
 * POST /api/translate-lines answers fast: the call asks only the requested language, and the other 6 languages
 * are filled afterwards in the background ({@link LineFill}), so the next learner in any language hits the cache.
 * The sentence path ({@link #lineFor}) still asks all languages in one call.
 */
@Service
public class LineTranslationService {

    private static final Logger log = LoggerFactory.getLogger(LineTranslationService.class);

    static final int MAX_TEXTS = 20;
    static final int MAX_TEXT = 500;
    static final int MAX_HEADWORD = 100;

    private final LineTranslationRepository lines;
    private final ClaudeService claude;
    private final ClaudeGate gate;
    private final Clock clock;
    private final LineFill fill;
    private final String promptVersion;
    /** The prompt_version of headword rows (TASK-106.8), e.g. "headword-v1"; kept apart from the line version. */
    private final String headwordPromptVersion;

    public LineTranslationService(LineTranslationRepository lines, ClaudeService claude, ClaudeGate gate, Clock clock,
            LineFill fill, @Value("${app.claude.line-prompt-version:v1}") String promptVersion,
            @Value("${app.claude.headword-prompt-version:v1}") String headwordPromptVersion) {
        this.headwordPromptVersion = "headword-" + headwordPromptVersion;
        this.lines = lines;
        this.claude = claude;
        this.gate = gate;
        this.clock = clock;
        this.fill = fill;
        this.promptVersion = promptVersion;
    }

    /** POST /api/translate-lines: the requested language first, the others later in the background. */
    public TranslateLinesResponse translate(TranslateLinesRequest request, boolean cachedOnly) {
        return translate(request, cachedOnly, false, true);
    }

    /**
     * {@code alreadyGated}: this request already passed {@link ClaudeGate#beforeNewCall} for its sentence, so the line
     * call only checks the money budget and does not use up a second allowance of the user's limit.
     * {@code fastFirst}: ask Claude for the requested language only and fill the rest in the background.
     */
    private TranslateLinesResponse translate(TranslateLinesRequest request, boolean cachedOnly, boolean alreadyGated,
            boolean fastFirst) {
        TargetLanguage lang = request.targetLang();
        if (lang == null || lang == TargetLanguage.EN) {
            throw bad("invalid_target_lang", "Choose a target language other than English.");
        }
        List<String> texts = request.texts();
        if (texts == null || texts.isEmpty() || texts.size() > MAX_TEXTS) {
            throw bad("invalid_texts", "Send 1-" + MAX_TEXTS + " texts.");
        }
        List<String> normalized = new ArrayList<>();
        for (String text : texts) {
            String clean = normalize(text);
            if (clean.isEmpty() || clean.length() > MAX_TEXT) {
                throw bad("invalid_texts", "Each text must be 1-" + MAX_TEXT + " characters.");
            }
            normalized.add(clean);
        }
        List<String> headwords = normalizedHeadwords(request.headwords(), texts.size());

        // One key per (text, headword): the same item twice is asked once.
        Map<String, Item> items = new LinkedHashMap<>();
        List<Item> itemOfText = new ArrayList<>();
        for (int i = 0; i < normalized.size(); i++) {
            Item item = new Item(normalized.get(i), headwords.get(i));
            itemOfText.add(items.computeIfAbsent(item.lineHash + "|" + item.headwordHash, key -> item));
        }

        String code = lang.code();
        Map<String, String> found = new HashMap<>();
        for (LineTranslation saved : lines.findByTargetLangAndPromptVersionAndTextHashIn(code, promptVersion,
                items.values().stream().map(Item::lineHash).collect(Collectors.toSet()))) {
            found.put(saved.getTextHash(), saved.getTranslation());
        }
        Map<String, String> foundHeadwords = new HashMap<>();
        Set<String> headwordHashes = items.values().stream().map(item -> item.headwordHash).filter(Objects::nonNull)
                .collect(Collectors.toSet());
        if (!headwordHashes.isEmpty()) {
            for (LineTranslation saved : lines.findByTargetLangAndPromptVersionAndTextHashIn(code,
                    headwordPromptVersion, headwordHashes)) {
                foundHeadwords.put(saved.getTextHash(), saved.getTranslation());
            }
        }
        List<Item> misses = items.values().stream()
                .filter(item -> !found.containsKey(item.lineHash)
                        || (item.headwordHash != null && !foundHeadwords.containsKey(item.headwordHash)))
                .toList();

        if (!cachedOnly && !misses.isEmpty()) {
            if (fastFirst) {
                askOneLanguage(lang, misses, alreadyGated, found, foundHeadwords);
                fillOtherLanguages(lang, misses);
            } else {
                askClaude(lang, misses, alreadyGated, found, foundHeadwords, null);
            }
        }

        List<TranslateLinesResponse.Line> answer = new ArrayList<>();
        for (int i = 0; i < texts.size(); i++) {
            Item item = itemOfText.get(i);
            String headword = item.headwordHash == null ? null : foundHeadwords.get(item.headwordHash);
            answer.add(new TranslateLinesResponse.Line(texts.get(i), found.get(item.lineHash),
                    item.lineWasSaved && found.containsKey(item.lineHash), headword));
        }
        return new TranslateLinesResponse(lang, answer);
    }

    /**
     * The language line of ONE sentence for the sentence answer (TASK-106.6), or empty when there is none.
     * The text is already normalized. Empty also when the text is too long for a line (over {@value #MAX_TEXT}),
     * when {@code cachedOnly} is set and the line is not saved, and when the call is refused or fails: the English
     * part is already paid and good, so a missing helper line must never cost the learner the whole answer.
     * With {@code store} false (personal text: email, phone, link) the line is neither read from nor saved to the
     * shared table; it is made fresh and thrown away.
     * {@code alreadyGated}: the sentence call of this same request already passed the gate, so only the budget is checked.
     */
    public Optional<String> lineFor(TargetLanguage lang, String normalizedText, boolean cachedOnly, boolean store,
            boolean alreadyGated) {
        if (lang == null || lang == TargetLanguage.EN || normalizedText.isEmpty() || normalizedText.length() > MAX_TEXT) {
            return Optional.empty();
        }
        try {
            if (store) {
                TranslateLinesResponse.Line line = translate(
                        new TranslateLinesRequest(lang, List.of(normalizedText)), cachedOnly, alreadyGated, false).lines().get(0);
                return Optional.ofNullable(line.translation());
            }
            if (cachedOnly) {
                return Optional.empty();
            }
            checkGate(alreadyGated);
            String line = claude.translateLines(lang, List.of(normalizedText)).get(0).strip();
            return line.isEmpty() ? Optional.empty() : Optional.of(line);
        } catch (RuntimeException e) {
            // A guest, the rate limit and the daily budget end here too (ApiException): the app shows its fallback.
            log.info("No language line for a sentence ({}): {}", lang.code(), e.toString());
            return Optional.empty();
        }
    }

    /** True when a sentence call should also write the line for this language (not English, not too long). */
    public boolean wantsLine(TargetLanguage lang, String normalizedText) {
        return lang != null && lang != TargetLanguage.EN && !normalizedText.isEmpty()
                && normalizedText.length() <= MAX_TEXT;
    }

    /**
     * The line the sentence call wrote for this text (TASK-115): save it like a line from the line call, so a later
     * {@link #lineFor} finds it, and return it. With {@code store} false (personal text) nothing is saved.
     * A saved line is never replaced; when one exists, the saved one is returned.
     */
    public String keepLine(TargetLanguage lang, String normalizedText, String line, boolean store) {
        if (!store) {
            return line;
        }
        String hash = hash(normalizedText);
        Optional<LineTranslation> saved = lines
                .findByTargetLangAndPromptVersionAndTextHashIn(lang.code(), promptVersion, Set.of(hash)).stream()
                .findFirst();
        if (saved.isPresent()) {
            return saved.get().getTranslation();
        }
        save(lang, hash, normalizedText, promptVersion, line);
        return line;
    }

    private void checkGate(boolean alreadyGated) {
        if (alreadyGated) {
            gate.checkBudget();
        } else {
            gate.beforeNewCall();
        }
    }

    /**
     * One call for every miss, in the requested language only: the fast answer of the language row. Lines and
     * headwords are saved and put into {@code found} and {@code foundHeadwords}.
     */
    private void askOneLanguage(TargetLanguage lang, List<Item> misses, boolean alreadyGated, Map<String, String> found,
            Map<String, String> foundHeadwords) {
        checkGate(alreadyGated);
        List<String> missTexts = misses.stream().map(Item::text).toList();
        List<WordLineAnswer.Item> translated;
        if (misses.stream().anyMatch(item -> item.headword != null)) {
            translated = claude.translateWordLines(lang, missTexts, misses.stream().map(Item::headword).toList());
        } else {
            translated = claude.translateLines(lang, missTexts).stream()
                    .map(line -> new WordLineAnswer.Item(line, null)).toList();
        }
        if (translated == null || translated.size() != missTexts.size()) {
            throw new IllegalStateException("Claude returned " + (translated == null ? 0 : translated.size())
                    + " lines for " + missTexts.size() + " texts.");
        }
        for (int i = 0; i < misses.size(); i++) {
            Item item = misses.get(i);
            WordLineAnswer.Item answer = translated.get(i);
            String line = answer.line() == null ? "" : answer.line().strip();
            // An empty line is not saved; the app shows its fallback. A saved line is never replaced.
            if (!line.isEmpty() && found.putIfAbsent(item.lineHash, line) == null) {
                item.lineWasSaved = false;
                save(lang, item.lineHash, item.text, promptVersion, line);
            }
            String headword = answer.headword() == null ? "" : answer.headword().strip();
            if (item.headwordHash != null && !headword.isEmpty()
                    && foundHeadwords.putIfAbsent(item.headwordHash, headword) == null) {
                save(lang, item.headwordHash, item.headword, headwordPromptVersion, headword);
            }
        }
    }

    /**
     * After the fast answer: the same misses in all languages, in the background, so the next learner in another
     * language hits the cache. The requested language is already saved; a saved row is never replaced. Only the
     * money budget is checked: the learner's own limit was used by the fast call. A failure is only logged.
     */
    private void fillOtherLanguages(TargetLanguage lang, List<Item> misses) {
        fill.run(() -> {
            try {
                // Fresh items: the request thread may still read the flags of its own.
                List<Item> copies = misses.stream().map(item -> new Item(item.text, item.headword)).toList();
                askClaude(lang, copies, true, new HashMap<>(), new HashMap<>(), lang);
            } catch (RuntimeException e) {
                log.info("Background line fill failed ({} texts): {}", misses.size(), e.toString());
            }
        });
    }

    /**
     * One call for every miss, in ALL languages (TASK-106.7): every line is saved, so a later learner in another
     * language hits the cache. With a headword in any miss the call also translates the headwords (TASK-106.8).
     * The lines and headwords of the requested language are put into {@code found} and {@code foundHeadwords}.
     * {@code alreadySaved}: a language whose rows the fast call already saved (not saved again), or null.
     */
    private void askClaude(TargetLanguage lang, List<Item> misses, boolean alreadyGated, Map<String, String> found,
            Map<String, String> foundHeadwords, TargetLanguage alreadySaved) {
        checkGate(alreadyGated);
        List<String> missTexts = misses.stream().map(Item::text).toList();
        List<WordLinesAnswer.Lines> translated;
        if (misses.stream().anyMatch(item -> item.headword != null)) {
            translated = claude.translateWordLinesAllLanguages(missTexts,
                    misses.stream().map(Item::headword).toList());
        } else {
            translated = claude.translateLinesAllLanguages(missTexts).stream()
                    .map(map -> new WordLinesAnswer.Lines(map, Map.of())).toList();
        }
        if (translated.size() != missTexts.size()) {
            throw new IllegalStateException("Claude returned " + translated.size() + " lines for "
                    + missTexts.size() + " texts.");
        }
        for (int i = 0; i < misses.size(); i++) {
            Item item = misses.get(i);
            WordLinesAnswer.Lines answer = translated.get(i);
            // An empty or missing line is not saved; the app shows its fallback. A saved line is never replaced.
            forEachLine(answer.lines(), (lineLang, text) -> {
                if (lineLang == alreadySaved) {
                    return;
                }
                if (lineLang == lang && found.putIfAbsent(item.lineHash, text) == null) {
                    item.lineWasSaved = false;
                }
                save(lineLang, item.lineHash, item.text, promptVersion, text);
            });
            if (item.headwordHash != null) {
                forEachLine(answer.headwords(), (lineLang, text) -> {
                    if (lineLang == alreadySaved) {
                        return;
                    }
                    if (lineLang == lang) {
                        foundHeadwords.putIfAbsent(item.headwordHash, text);
                    }
                    save(lineLang, item.headwordHash, item.headword, headwordPromptVersion, text);
                });
            }
        }
    }

    private static void forEachLine(Map<TargetLanguage, String> lines, BiConsumer<TargetLanguage, String> action) {
        lines.forEach((lineLang, value) -> {
            String text = value == null ? "" : value.strip();
            if (!text.isEmpty() && lineLang != TargetLanguage.EN) {
                action.accept(lineLang, text);
            }
        });
    }

    private void save(TargetLanguage lang, String hash, String text, String version, String line) {
        try {
            lines.saveAndFlush(new LineTranslation(hash, text, lang.code(), version, line, "llm",
                    clock.instant()));
        } catch (DataIntegrityViolationException e) {
            // Another request saved the same line at the same moment. Ours is still a good answer.
        }
    }

    /** Trim and collapse inner whitespace to one space. */
    static String normalize(String text) {
        return text == null ? "" : text.strip().replaceAll("\\s+", " ");
    }

    static String hash(String normalizedText) {
        return CacheKeys.key(normalizedText);
    }

    /** The key of a headword row: the headword together with the sense text, so each sense has its own word. */
    static String headwordHash(String normalizedHeadword, String normalizedText) {
        return CacheKeys.key("headword", normalizedHeadword, normalizedText);
    }

    /** One entry per text: the normalized headword, or null when none is asked. */
    private static List<String> normalizedHeadwords(List<String> headwords, int size) {
        List<String> result = new ArrayList<>();
        if (headwords != null && headwords.size() != size) {
            throw bad("invalid_headwords", "Send one headword (or null) for each text.");
        }
        for (int i = 0; i < size; i++) {
            String clean = headwords == null ? "" : normalize(headwords.get(i));
            if (clean.length() > MAX_HEADWORD) {
                throw bad("invalid_headwords", "Each headword must be at most " + MAX_HEADWORD + " characters.");
            }
            result.add(clean.isEmpty() ? null : clean);
        }
        return result;
    }

    /** One text to ask: the sense text and its optional headword, with their row keys. */
    private static final class Item {
        final String text;
        final String headword;
        final String lineHash;
        final String headwordHash;
        /** False when the line in the requested language comes from this request's call, not from the table. */
        boolean lineWasSaved = true;

        Item(String text, String headword) {
            this.text = text;
            this.headword = headword;
            this.lineHash = hash(text);
            this.headwordHash = headword == null ? null : LineTranslationService.headwordHash(headword, text);
        }

        String text() {
            return text;
        }

        String headword() {
            return headword;
        }

        String lineHash() {
            return lineHash;
        }

    }

    private static ApiException bad(String code, String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, code, message);
    }
}
