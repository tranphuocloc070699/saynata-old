package com.englishtranslation.backend.word;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.englishtranslation.backend.cache.CacheKeys;
import com.englishtranslation.backend.claude.ClaudeProperties;
import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.dictionary.DictionarySense;
import com.englishtranslation.backend.dictionary.DictionaryWord;
import com.englishtranslation.backend.dictionary.DictionaryWordRepository;
import com.englishtranslation.backend.limits.ClaudeGate;
import java.util.List;
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

/** TASK-118: a form ("ran", "contaminated", "gave up") is answered from its lemma's entry, with matchedForm. */
@SpringBootTest(properties = "app.claude.api-key=test-key")
@AutoConfigureMockMvc
class WordFormLookupTest {

    static String entry(String pos, String definition) {
        return "{\"senses\":[{\"pos\":\"" + pos + "\",\"cefr\":\"B2\",\"simpleDefinition\":\"" + definition + "\","
                + "\"vietnamese\":\"x\",\"examples\":[],\"usage\":[]}]}";
    }

    @Autowired
    MockMvc mockMvc;
    @Autowired
    WordLookupRepository lookups;
    @Autowired
    DictionaryWordRepository bundled;
    @Autowired
    ClaudeProperties properties;
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
        jdbc.update("delete from word_form");
        jdbc.update("delete from dictionary_form");
        jdbc.update("delete from word_lookup_media");
        lookups.deleteAll();
        bundled.deleteAll();
    }

    private void saveCached(String word, String entryJson) {
        lookups.save(new WordLookup(CacheKeys.key("word", properties.wordPromptVersion(), word), word, entryJson,
                "claude-haiku-5-5", properties.wordPromptVersion()));
    }

    private void saveForm(String form, String lemma, String type) {
        jdbc.update("insert into word_form (form, lemma, form_type, kind) values (?, ?, ?, ?)",
                form, lemma, type, form.contains(" ") ? "phrase" : "word");
    }

    private ResultActions lookUp(String text, boolean cachedOnly) throws Exception {
        return mockMvc.perform(get("/api/words/{word}", text).param("cachedOnly", String.valueOf(cachedOnly)));
    }

    @Test
    void aFormOfACachedWordIsAnsweredFromTheLemmaWithoutClaude() throws Exception {
        saveCached("contaminate", entry("verb", "to make something dirty or harmful"));
        saveForm("contaminated", "contaminate", "past tense");

        for (boolean cachedOnly : new boolean[] {true, false}) {
            lookUp("Contaminated", cachedOnly).andExpect(status().isOk())
                    .andExpect(jsonPath("$.word").value("contaminate"))
                    .andExpect(jsonPath("$.cached").value(true))
                    .andExpect(jsonPath("$.matchedForm.text").value("contaminated"))
                    .andExpect(jsonPath("$.matchedForm.type").value("past tense"))
                    .andExpect(jsonPath("$.entry.senses[0].simpleDefinition").value("to make something dirty or harmful"));
        }

        verifyNoInteractions(claude, gate);
        assertThat(lookups.count()).isEqualTo(1);
    }

    @Test
    void aFormOfABundledWordIsAnsweredFromTheBundledEntry() throws Exception {
        DictionaryWord run = new DictionaryWord("run", 5, "/rʌn/");
        DictionarySense sense = new DictionarySense(run, 0);
        sense.setText("verb", "A1", "to move fast on your legs", "chạy", "[]", "[]");
        run.getSenses().add(sense);
        run = bundled.save(run);
        jdbc.update("insert into dictionary_form (word_id, form, form_type) values (?, 'ran', 'past tense')", run.getId());

        lookUp("ran", false).andExpect(status().isOk())
                .andExpect(jsonPath("$.word").value("run"))
                .andExpect(jsonPath("$.ipa").value("/rʌn/"))
                .andExpect(jsonPath("$.matchedForm.text").value("ran"))
                .andExpect(jsonPath("$.matchedForm.type").value("past tense"))
                .andExpect(jsonPath("$.entry.senses[0].simpleDefinition").value("to move fast on your legs"));

        verifyNoInteractions(claude, gate);
        assertThat(lookups.count()).isZero();
    }

    @Test
    void aWordWithItsOwnEntryWinsOverItsLemma() throws Exception {
        saveCached("glass", entry("noun", "a hard clear material"));
        saveCached("glasses", entry("noun", "two pieces of glass you wear to see better"));
        saveForm("glasses", "glass", "plural");

        lookUp("glasses", false).andExpect(status().isOk())
                .andExpect(jsonPath("$.word").value("glasses"))
                .andExpect(jsonPath("$.matchedForm").doesNotExist())
                .andExpect(jsonPath("$.entry.senses[0].simpleDefinition").value("two pieces of glass you wear to see better"));

        verifyNoInteractions(claude, gate);
    }

    @Test
    void aFormWhoseLemmaHasNoEntryKeepsTheOldFlow() throws Exception {
        saveForm("repatriated", "repatriate", "past tense");
        when(claude.describeWord("repatriated")).thenReturn(new WordEntry(List.of()));

        lookUp("repatriated", true).andExpect(status().isNotFound());
        lookUp("repatriated", false).andExpect(status().isOk())
                .andExpect(jsonPath("$.word").value("repatriated"))
                .andExpect(jsonPath("$.matchedForm").doesNotExist());

        verify(claude).describeWord("repatriated");
    }

    @Test
    void aPhraseFormIsAnsweredFromTheCachedPhrase() throws Exception {
        saveCached("give up", entry("phrasal verb", "to stop trying to do something"));
        saveForm("gave up", "give up", "past tense");

        lookUp("gave up", false).andExpect(status().isOk())
                .andExpect(jsonPath("$.word").value("give up"))
                .andExpect(jsonPath("$.matchedForm.text").value("gave up"))
                .andExpect(jsonPath("$.matchedForm.type").value("past tense"));

        verifyNoInteractions(claude, gate);
    }
}
