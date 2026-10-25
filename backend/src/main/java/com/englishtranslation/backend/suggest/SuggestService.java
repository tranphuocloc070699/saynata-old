package com.englishtranslation.backend.suggest;

import com.englishtranslation.backend.claude.ClaudeProperties;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

/**
 * Prefix suggestions while the user types (TASK-83.4): bundled words, cached backend words and cached phrases.
 * Only text that already has an answer is suggested, so tapping one is a cache hit, never a Claude call.
 *
 * Each source is one LIMITed query on a prefix index (V19), so the whole call stays far under 50 ms. The cached
 * words and phrases are not sorted in SQL on purpose: "ORDER BY LENGTH" would read every match first (89 ms for
 * 200,000 phrases on "p"), while a plain LIMIT stops after a few rows (under 1 ms). Java sorts the few rows.
 *
 * Popularity (TASK-116) follows the same rule: after the LIMITed queries, one IN query counts how many people
 * looked up each candidate (history_item, V36 index) and Java sorts by it. Never ORDER BY count over all matches.
 * A phrase also matches from any of its words ("up" finds "give up"), through a trigram index (V36).
 */
@Service
public class SuggestService {

    static final int MAX_SUGGESTIONS = 8;
    /** When there are phrases, words keep at most this many places, so a phrase still shows. */
    static final int MAX_WORDS_WITH_PHRASES = 5;
    static final int MAX_PREFIX_LENGTH = 100;
    /** Rows read from the cached words and the cached phrases, before sorting and removing duplicates. */
    static final int ROWS_PER_SOURCE = 24;

    private final JdbcClient jdbc;
    private final ClaudeProperties properties;

    public SuggestService(JdbcClient jdbc, ClaudeProperties properties) {
        this.jdbc = jdbc;
        this.properties = properties;
    }

    /**
     * Words first (an exact match first, then the words most people looked up, then bundled words by NGSL rank,
     * then cached words, shorter first), then phrases (most looked up, then starts-with before word-start, shorter first). {@code lang} is kept so old apps still work; since prompt v10 a cached sentence has no language (TASK-106.6),
     * so it does not limit the phrases any more.
     */
    public SuggestResponse suggest(String rawPrefix, String lang) {
        String prefix = normalize(rawPrefix);
        if (prefix.isEmpty()) {
            return new SuggestResponse(prefix, List.of());
        }
        String like = escapeLike(prefix) + "%";

        Set<String> wordRows = new LinkedHashSet<>();
        wordRows.addAll(bundledWords(like));
        wordRows.addAll(cachedWords(like));
        List<String> phraseRows = cachedPhrases(prefix, like);

        // One IN query for all candidates, then a stable sort in Java: most people first, the rest keep their order.
        Map<String, Integer> popularity = popularity(wordRows, phraseRows);
        List<String> sortedWords = mostPopularFirst(wordRows, popularity);
        Set<String> words = new LinkedHashSet<>();
        if (wordRows.contains(prefix)) {
            words.add(prefix);
        }
        words.addAll(sortedWords);

        // Keep one phrase per lower-case text, and none that is a word.
        Set<String> seen = new HashSet<>(words);
        List<String> phrases = new ArrayList<>();
        for (String phrase : mostPopularFirst(phraseRows, popularity)) {
            if (seen.add(phrase.toLowerCase(Locale.ROOT))) {
                phrases.add(phrase);
            }
        }

        int wordPlaces = phrases.isEmpty() ? MAX_SUGGESTIONS
                : Math.max(MAX_WORDS_WITH_PHRASES, MAX_SUGGESTIONS - phrases.size());
        List<Suggestion> suggestions = new ArrayList<>();
        words.stream().limit(wordPlaces).forEach(word -> suggestions.add(Suggestion.word(word)));
        phrases.stream().limit(MAX_SUGGESTIONS - suggestions.size())
                .forEach(phrase -> suggestions.add(Suggestion.phrase(phrase)));
        return new SuggestResponse(prefix, suggestions);
    }

    private List<String> bundledWords(String like) {
        return jdbc.sql("""
                SELECT lemma FROM dictionary_word
                WHERE lemma LIKE :like ESCAPE '\\'
                ORDER BY word_rank, lemma
                LIMIT :limit""")
                .param("like", like)
                .param("limit", MAX_SUGGESTIONS)
                .query(String.class).list();
    }

    /** Only rows of the current prompt version: older rows are not cache hits any more. Shorter first. */
    private List<String> cachedWords(String like) {
        return shortestFirst(jdbc.sql("""
                SELECT word FROM word_lookup
                WHERE word LIKE :like ESCAPE '\\' AND prompt_version = :version
                LIMIT :limit""")
                .param("like", like)
                .param("version", properties.wordPromptVersion())
                .param("limit", ROWS_PER_SOURCE)
                .query(String.class).list());
    }

    /**
     * Phrases that start with the text, then phrases with a word that starts with it ("give up" for "up").
     * Each group is shorter first. Two spellings of one text are one suggestion, so more rows than needed are read.
     */
    private List<String> cachedPhrases(String prefix, String like) {
        List<String> phrases = new ArrayList<>(phrasesLike(like));
        phrases.addAll(phrasesLike("% " + escapeLike(prefix) + "%"));
        return phrases;
    }

    private List<String> phrasesLike(String pattern) {
        return shortestFirst(jdbc.sql("""
                SELECT source_text FROM sentence_translation
                WHERE LOWER(source_text) LIKE :like ESCAPE '\\' AND prompt_version = :version
                LIMIT :limit""")
                .param("like", pattern)
                .param("version", properties.sentencePromptVersion())
                .param("limit", ROWS_PER_SOURCE)
                .query(String.class).list());
    }

    /** How many different people looked up each candidate: lower-case text to number of people. One IN query. */
    private Map<String, Integer> popularity(Collection<String> words, Collection<String> phrases) {
        Set<String> keys = new HashSet<>();
        words.forEach(text -> keys.add(normalize(text)));
        phrases.forEach(text -> keys.add(normalize(text)));
        Map<String, Integer> counts = new HashMap<>();
        if (keys.isEmpty()) {
            return counts;
        }
        jdbc.sql("""
                SELECT text_key, COUNT(DISTINCT user_id) AS users FROM history_item
                WHERE kind = 'word' AND deleted = FALSE AND text_key IN (:keys)
                GROUP BY text_key""")
                .param("keys", keys)
                .query((rs, row) -> counts.put(rs.getString("text_key"), rs.getInt("users")))
                .list();
        return counts;
    }

    /** Stable sort: most people first; texts nobody looked up keep their order. */
    private static List<String> mostPopularFirst(Collection<String> texts, Map<String, Integer> popularity) {
        return texts.stream()
                .sorted(Comparator.comparingInt((String text) -> popularity.getOrDefault(normalize(text), 0)).reversed())
                .toList();
    }

    private static List<String> shortestFirst(List<String> texts) {
        return texts.stream().sorted(Comparator.comparingInt(String::length).thenComparing(Comparator.naturalOrder()))
                .toList();
    }

    /** Lower case, spaces trimmed and squeezed, cut to the column-safe length. */
    static String normalize(String prefix) {
        if (prefix == null) {
            return "";
        }
        String normalized = prefix.strip().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT);
        return normalized.length() > MAX_PREFIX_LENGTH ? normalized.substring(0, MAX_PREFIX_LENGTH) : normalized;
    }

    /** "50%" must find "50%..." and not every text starting with "50". */
    static String escapeLike(String text) {
        return text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    }
}
