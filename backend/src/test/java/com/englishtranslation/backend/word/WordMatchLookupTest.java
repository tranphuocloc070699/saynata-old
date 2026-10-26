package com.englishtranslation.backend.word;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.englishtranslation.backend.cache.CacheKeys;
import com.englishtranslation.backend.claude.LlmProperties;
import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.limits.ClaudeGate;
import com.englishtranslation.backend.limits.RateLimiter;
import com.englishtranslation.backend.limits.SignInRequiredException;
import com.englishtranslation.backend.translation.SentenceSourceAlias;
import com.englishtranslation.backend.translation.SentenceSourceAliasRepository;
import com.englishtranslation.backend.translation.SentenceTranslation;
import com.englishtranslation.backend.translation.SentenceTranslationRepository;
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

/**
 * TASK-114.5: a phrase (or a word missing from the word list) that the sentence endpoint returned as a wordMatch
 * may be described by Claude. Any other phrase stays cache-only. Claude and the gate are mocks; nothing is paid.
 */
@SpringBootTest(properties = {
        "app.claude.api-key=test-key",
        "app.auth.require-sign-in=true"
})
@AutoConfigureMockMvc
class WordMatchLookupTest {

    @Autowired
    MockMvc mockMvc;
    @Autowired
    WordLookupRepository lookups;
    @Autowired
    SentenceTranslationRepository sentences;
    @Autowired
    SentenceSourceAliasRepository aliases;
    @Autowired
    LlmProperties properties;
    @Autowired
    JdbcTemplate jdbc;
    @Autowired
    RateLimiter rateLimiter;

    @MockitoBean
    ClaudeService claude;
    @MockitoBean
    ClaudeGate gate;

    @BeforeEach
    @AfterEach
    void cleanUp() {
        jdbc.update("delete from word_lookup_media");
        lookups.deleteAll();
        aliases.deleteAll();
        sentences.deleteAll();
        rateLimiter.reset();
    }

    /** What the sentence endpoint leaves behind for a typed non-English text: an English row plus an alias with the wordMatch. */
    private void saveAlias(String version, String typedText, String wordMatch) {
        String englishKey = CacheKeys.sentenceKey(version, "english of " + typedText);
        sentences.save(new SentenceTranslation(englishKey, "english of " + typedText, "en", "A meaning.", "[]", "", "m",
                version));
        aliases.save(new SentenceSourceAlias(CacheKeys.sentenceSourceKey(version, typedText), englishKey, "vi",
                wordMatch));
    }

    private ResultActions word(String text, boolean cachedOnly) throws Exception {
        return mockMvc.perform(get("/api/words/{word}", text).param("cachedOnly", String.valueOf(cachedOnly)));
    }

    @Test
    void aWordMatchPhraseCallsClaudeOnceThenIsCached() throws Exception {
        saveAlias(properties.sentencePromptVersion(), "bỏ cuộc", "give up");
        when(claude.describeWord("give up")).thenReturn(new WordEntry(List.of()));

        word("give up", false).andExpect(status().isOk()).andExpect(jsonPath("$.cached").value(false));
        word("give up", false).andExpect(status().isOk()).andExpect(jsonPath("$.cached").value(true));

        verify(gate, times(1)).beforeNewCall();
        verify(claude, times(1)).describeWord("give up");
        assertThat(lookups.count()).isEqualTo(1);
    }

    @Test
    void aPhraseThatIsNotAWordMatchStaysCacheOnly() throws Exception {
        saveAlias(properties.sentencePromptVersion(), "bỏ cuộc", "give up");

        word("look forward to", false).andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("not_cached"));

        verifyNoInteractions(claude, gate);
        assertThat(lookups.count()).isZero();
    }

    @Test
    void cachedOnlyNeverCallsClaudeEvenForAWordMatch() throws Exception {
        saveAlias(properties.sentencePromptVersion(), "bỏ cuộc", "give up");

        word("give up", true).andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("not_cached"));

        verifyNoInteractions(claude, gate);
    }

    @Test
    void aGuestGets401SignInRequiredForAWordMatch() throws Exception {
        saveAlias(properties.sentencePromptVersion(), "bỏ cuộc", "give up");
        doThrow(new SignInRequiredException()).when(gate).beforeNewCall();

        word("give up", false).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("sign_in_required"));

        verify(claude, never()).describeWord(anyString());
        assertThat(lookups.count()).isZero();
    }

    @Test
    void aOneWordMatchMissingFromTheWordListWorks() throws Exception {
        assertThat(new EnglishWords().contains("zzqxvword")).isFalse();
        // Without the alias it is "not a word" and Claude is not called.
        word("zzqxvword", false).andExpect(status().isOk());
        verifyNoInteractions(claude, gate);

        saveAlias(properties.sentencePromptVersion(), "xyz", "zzqxvword");
        when(claude.describeWord("zzqxvword")).thenReturn(new WordEntry(List.of()));

        word("zzqxvword", false).andExpect(status().isOk()).andExpect(jsonPath("$.cached").value(false));

        verify(claude, times(1)).describeWord("zzqxvword");
    }

    @Test
    void anAliasOfAnOldSentencePromptVersionIsIgnored() throws Exception {
        saveAlias("v1-old", "bỏ cuộc", "give up");

        word("give up", false).andExpect(status().isNotFound()).andExpect(jsonPath("$.code").value("not_cached"));

        verifyNoInteractions(claude, gate);
    }
}
