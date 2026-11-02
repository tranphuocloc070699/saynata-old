package com.englishtranslation.backend.vision;

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

import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.limits.ClaudeGate;
import com.englishtranslation.backend.limits.RateLimiter;
import com.englishtranslation.backend.limits.SignInRequiredException;
import com.englishtranslation.backend.word.WordEntry;
import com.englishtranslation.backend.word.WordLookupRepository;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/**
 * TASK-121.1: GET /api/words/{label} may describe the 30 dishes (with or without accents) and the labels the vision
 * endpoint returned. Any other text that is not an English word stays "not a word". Claude and the gate are mocks.
 */
@SpringBootTest(properties = { "app.claude.api-key=test-key", "app.auth.require-sign-in=true" })
@AutoConfigureMockMvc
class VisionWordLabelsTest {

    @Autowired
    MockMvc mockMvc;
    @Autowired
    WordLookupRepository lookups;
    @Autowired
    VisionIdentifyRepository visionRows;
    @Autowired
    VisionLabels labels;
    @Autowired
    JdbcTemplate jdbc;
    @Autowired
    RateLimiter rateLimiter;
    @Value("${app.claude.vision-prompt-version}")
    String visionVersion;

    @MockitoBean
    ClaudeService claude;
    @MockitoBean
    ClaudeGate gate;

    @BeforeEach
    @AfterEach
    void cleanUp() {
        jdbc.update("delete from word_lookup_media");
        lookups.deleteAll();
        visionRows.deleteAll();
        rateLimiter.reset();
    }

    private ResultActions word(String text) throws Exception {
        return mockMvc.perform(get("/api/words/{word}", text));
    }

    private void saveVisionLabel(String label, String version) {
        visionRows.save(new VisionIdentify("h" + label, version, label, "object", 0.9, "m", Instant.now()));
    }

    @Test
    void thereAre30DishesAndEachHasAnUnaccentedAlias() {
        assertThat(labels.dish("phở")).contains("phở");
        assertThat(labels.dish("pho")).contains("phở");
        assertThat(labels.dish("banh mi")).contains("bánh mì");
        assertThat(labels.dish("bun bo hue")).contains("bún bò huế");
        assertThat(labels.dish("banh duc")).contains("bánh đúc");
        assertThat(labels.dish("hamburger")).isEmpty();
        long count = new BufferedReader(new InputStreamReader(getClass().getResourceAsStream("/words/dishes.txt"),
                StandardCharsets.UTF_8)).lines().filter(line -> !line.isBlank()).count();
        assertThat(count).isEqualTo(30);
    }

    @Test
    void aDishWithAccentsIsDescribedByClaude() throws Exception {
        when(claude.describeWord("phở")).thenReturn(new WordEntry(List.of()));

        word("phở").andExpect(status().isOk()).andExpect(jsonPath("$.word").value("phở"))
                .andExpect(jsonPath("$.cached").value(false));
        word("phở").andExpect(status().isOk()).andExpect(jsonPath("$.cached").value(true));

        verify(claude, times(1)).describeWord("phở");
    }

    @Test
    void aDishWithoutAccentsMapsToTheAccentedEntry() throws Exception {
        when(claude.describeWord("bánh mì")).thenReturn(new WordEntry(List.of()));

        word("Banh mi").andExpect(status().isOk()).andExpect(jsonPath("$.word").value("bánh mì"));

        verify(claude, times(1)).describeWord("bánh mì");
        assertThat(lookups.count()).isEqualTo(1);
    }

    @Test
    void aGuestStillGetsSignInRequiredForADish() throws Exception {
        doThrow(new SignInRequiredException()).when(gate).beforeNewCall();

        word("phở").andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value("sign_in_required"));

        verify(claude, never()).describeWord(anyString());
    }

    @Test
    void aLabelTheVisionEndpointReturnedIsDescribedByClaude() throws Exception {
        // Before: not an English word, so no Claude call.
        word("zzqxvteapot").andExpect(status().isOk());
        verifyNoInteractions(claude);

        saveVisionLabel("zzqxvteapot", visionVersion);
        when(claude.describeWord("zzqxvteapot")).thenReturn(new WordEntry(List.of()));

        word("zzqxvteapot").andExpect(status().isOk()).andExpect(jsonPath("$.cached").value(false));

        verify(claude, times(1)).describeWord("zzqxvteapot");
    }

    @Test
    void aVisionPhraseWithASpaceIsDescribedToo() throws Exception {
        saveVisionLabel("zzqxv red bicycle", visionVersion);
        when(claude.describeWord("zzqxv red bicycle")).thenReturn(new WordEntry(List.of()));

        word("zzqxv red bicycle").andExpect(status().isOk());

        verify(claude, times(1)).describeWord("zzqxv red bicycle");
    }

    @Test
    void aLabelFromAnOldVisionPromptVersionIsIgnored() throws Exception {
        saveVisionLabel("zzqxvold", "v0-old");

        word("zzqxvold").andExpect(status().isOk());

        verifyNoInteractions(claude, gate);
    }

    @Test
    void anUnknownLabelIsStillNotAWordAndNeverCallsClaude() throws Exception {
        word("zzqxvunknown").andExpect(status().isOk()).andExpect(jsonPath("$.entry.senses.length()").value(0));
        word("zzqxv unknown phrase").andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("not_cached"));

        verifyNoInteractions(claude, gate);
    }
}
