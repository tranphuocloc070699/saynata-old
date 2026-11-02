package com.englishtranslation.backend.term;

import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.englishtranslation.backend.cache.CacheKeys;
import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.claude.LlmProperties;
import com.englishtranslation.backend.limits.ClaudeGate;
import com.englishtranslation.backend.word.WordLookup;
import com.englishtranslation.backend.word.WordLookupRepository;
import org.hamcrest.Matchers;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/** TASK-119.1: terms below an English word ("swift"), or alone for a text that is not a word ("nuxtjs"). */
@SpringBootTest(properties = "app.claude.api-key=test-key")
@AutoConfigureMockMvc
class TermLookupTest {

    @Autowired
    MockMvc mockMvc;
    @Autowired
    WordLookupRepository lookups;
    @Autowired
    LlmProperties properties;
    @Autowired
    JdbcTemplate jdbc;

    @MockitoBean
    ClaudeService claude;
    @MockitoBean
    ClaudeGate gate;

    @BeforeEach
    @AfterEach
    void cleanUp() {
        // The database is shared with other test classes, so leave nothing behind.
        jdbc.update("delete from term_alias");
        jdbc.update("delete from term");
        jdbc.update("delete from word_lookup_media");
        lookups.deleteAll();
    }

    private long saveTerm(String qid, String name, String field, String definition, String site, int popularity,
            String... aliases) {
        jdbc.update("insert into term (wikidata_id, name, field, simple_definition, official_url, wikipedia_url, popularity)"
                + " values (?, ?, ?, ?, ?, ?, ?)", qid, name, field, definition, site,
                "https://en.wikipedia.org/wiki/" + name.replace(' ', '_'), popularity);
        long id = jdbc.queryForObject("select id from term where wikidata_id = ?", Long.class, qid);
        for (String alias : java.util.Arrays.stream(aliases).map(TermKeys::key).distinct().toList()) {
            jdbc.update("insert into term_alias (alias_key, term_id, source) values (?, ?, 'wikidata')",
                    alias, id);
        }
        return id;
    }

    private void saveCached(String word, String definition) {
        String entry = "{\"senses\":[{\"pos\":\"adjective\",\"cefr\":\"C1\",\"simpleDefinition\":\"" + definition
                + "\",\"vietnamese\":\"x\",\"examples\":[],\"usage\":[]}]}";
        lookups.save(new WordLookup(CacheKeys.key("word", properties.wordPromptVersion(), word), word, entry,
                "claude-haiku-5-5", properties.wordPromptVersion()));
    }

    private ResultActions lookUp(String text, boolean cachedOnly) throws Exception {
        return mockMvc.perform(get("/api/words/{word}", text).param("cachedOnly", String.valueOf(cachedOnly)));
    }

    @Test
    void aTermIsShownBelowTheEnglishSensesNeverInPlaceOfThem() throws Exception {
        saveCached("swift", "happening or moving fast");
        saveTerm("Q17118377", "Swift", "programming language", "A language from Apple for making iPhone apps.",
                "https://www.swift.org", 60, "Swift");

        lookUp("swift", false).andExpect(status().isOk())
                .andExpect(jsonPath("$.word").value("swift"))
                .andExpect(jsonPath("$.entry.senses[0].simpleDefinition").value("happening or moving fast"))
                .andExpect(jsonPath("$.terms.length()").value(1))
                .andExpect(jsonPath("$.terms[0].name").value("Swift"))
                .andExpect(jsonPath("$.terms[0].field").value("programming language"))
                .andExpect(jsonPath("$.terms[0].officialUrl").value("https://www.swift.org"))
                .andExpect(jsonPath("$.terms[0].wikipediaUrl").value("https://en.wikipedia.org/wiki/Swift"));

        verifyNoInteractions(claude, gate);
    }

    @Test
    void aTextThatIsOnlyATermIsAnsweredWithItsTermsWithoutClaude() throws Exception {
        saveTerm("Q55697000", "Nuxt", "JavaScript framework", null, "https://nuxt.com", 20, "Nuxt", "Nuxt.js", "NuxtJS");

        for (String typed : new String[] {"nuxtjs", "Nuxtjs", "nuxt.js", "Nuxt.JS", "nuxt js"}) {
            for (boolean cachedOnly : new boolean[] {true, false}) {
                lookUp(typed, cachedOnly).andExpect(status().isOk())
                        .andExpect(header().string("Cache-Control", Matchers.containsString("public")))
                        .andExpect(jsonPath("$.entry.senses.length()").value(0))
                        .andExpect(jsonPath("$.terms[0].name").value("Nuxt"))
                        .andExpect(jsonPath("$.terms[0].officialUrl").value("https://nuxt.com"))
                        .andExpect(jsonPath("$.terms[0].simpleDefinition").doesNotExist());
            }
        }

        verifyNoInteractions(claude, gate);
    }

    @Test
    void aSharedAliasShowsAtMostThreeTermsMostPopularFirst() throws Exception {
        saveTerm("Q1", "TS one", "a", null, null, 5, "qxts");
        saveTerm("Q2", "TypeScript", "programming language", null, "https://www.typescriptlang.org", 90, "qxts");
        saveTerm("Q3", "TS three", "c", null, null, 40, "qxts");
        saveTerm("Q4", "TS four", "d", null, null, 1, "qxts");

        lookUp("qxts", false).andExpect(status().isOk())
                .andExpect(jsonPath("$.terms.length()").value(3))
                .andExpect(jsonPath("$.terms[0].name").value("TypeScript"))
                .andExpect(jsonPath("$.terms[1].name").value("TS three"))
                .andExpect(jsonPath("$.terms[2].name").value("TS one"));
    }

    @Test
    void aWordWithoutTermsHasNoTermsField() throws Exception {
        saveCached("swift", "happening or moving fast");

        lookUp("swift", false).andExpect(status().isOk())
                .andExpect(jsonPath("$.terms").doesNotExist());
        lookUp("nuxtjs", false).andExpect(status().isOk())
                .andExpect(jsonPath("$.entry.senses.length()").value(0))
                .andExpect(jsonPath("$.terms").doesNotExist());

        verifyNoInteractions(claude, gate);
    }
}
