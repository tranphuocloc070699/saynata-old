package com.englishtranslation.backend.lines;

import static com.englishtranslation.backend.lines.LinesFixtures.item;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.englishtranslation.backend.auth.AccessTokenService;
import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.claude.WordLinesAnswer;
import com.englishtranslation.backend.translation.TargetLanguage;
import com.englishtranslation.backend.user.User;
import com.englishtranslation.backend.user.UserRepository;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/** POST /api/translate-lines with headwords (TASK-106.8): the headword per sense, saved apart from the v1 line. */
@SpringBootTest(properties = { "app.claude.api-key=test-key", "app.auth.require-sign-in=true" })
@AutoConfigureMockMvc
class TranslateLinesHeadwordTest {

    @Autowired
    MockMvc mockMvc;
    @Autowired
    LineTranslationRepository lines;
    @Autowired
    AccessTokenService accessTokens;
    @Autowired
    UserRepository users;

    @MockitoBean
    ClaudeService claude;

    private String token;

    @BeforeEach
    void setUp() {
        lines.deleteAll();
        long id = users.findByEmail("headword@example.com")
                .orElseGet(() -> users.save(User.appUser("headword@example.com")))
                .getId();
        token = accessTokens.createToken(id);
    }

    private ResultActions send(String query, String body, boolean signedIn) throws Exception {
        var request = post("/api/translate-lines" + query).contentType(MediaType.APPLICATION_JSON).content(body);
        if (signedIn) {
            request.header("Authorization", "Bearer " + token);
        }
        return mockMvc.perform(request);
    }

    private static WordLinesAnswer.Lines lines(String line, String headword) {
        return new WordLinesAnswer.Lines(item(line), headword == null ? Map.of() : item(headword));
    }

    private static final String BANK = """
            {"targetLang":"ja","texts":["a place that keeps your money","the land next to a river"],
             "headwords":["bank","bank"]}""";

    @Test
    void eachSenseGetsItsOwnHeadwordInOneCall() throws Exception {
        when(claude.translateWordLinesAllLanguages(anyList(), anyList()))
                .thenReturn(List.of(lines("お金を預ける所", "銀行"), lines("川のそばの土地", "土手")));

        send("", BANK, true).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].translation").value("お金を預ける所"))
                .andExpect(jsonPath("$.lines[0].headword").value("銀行"))
                .andExpect(jsonPath("$.lines[1].headword").value("土手"));

        verify(claude, times(1)).translateWordLinesAllLanguages(
                List.of("a place that keeps your money", "the land next to a river"), List.of("bank", "bank"));
        verify(claude, never()).translateLinesAllLanguages(anyList());
        // 2 senses x 7 languages, each a line row and a headword row.
        assertThat(lines.findAll()).hasSize(28);

        // Another language is cached, line and headword, with no new call.
        send("?cachedOnly=true", BANK.replace("\"ja\"", "\"ko\""), false).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[1].headword").value("土手"))
                .andExpect(jsonPath("$.lines[1].cached").value(true));
        verify(claude, times(1)).translateWordLinesAllLanguages(anyList(), anyList());
    }

    @Test
    void aSavedV1LineIsKeptAndOnlyTheMissingHeadwordIsAsked() throws Exception {
        String text = "a person who writes computer code";
        lines.save(new LineTranslation(LineTranslationService.hash(text), text, "ja", "v1", "コードを書く人", "codex",
                Instant.now()));
        when(claude.translateWordLinesAllLanguages(anyList(), anyList()))
                .thenReturn(List.of(lines("new line", "プログラマー")));

        send("", "{\"targetLang\":\"ja\",\"texts\":[\"" + text + "\"],\"headwords\":[\"programmer\"]}", true)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].translation").value("コードを書く人"))
                .andExpect(jsonPath("$.lines[0].cached").value(true))
                .andExpect(jsonPath("$.lines[0].headword").value("プログラマー"));

        LineTranslation kept = lines.findByTargetLangAndPromptVersionAndTextHashIn("ja", "v1",
                List.of(LineTranslationService.hash(text))).get(0);
        assertThat(kept.getTranslation()).isEqualTo("コードを書く人");
        assertThat(lines.findByTargetLangAndPromptVersionAndTextHashIn("ja", "headword-v1",
                List.of(LineTranslationService.headwordHash("programmer", text)))).hasSize(1);
    }

    @Test
    void cachedOnlyWithAMissingHeadwordNeverCallsTheModel() throws Exception {
        send("?cachedOnly=true", BANK, false).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].translation").doesNotExist())
                .andExpect(jsonPath("$.lines[0].headword").doesNotExist());
        verify(claude, never()).translateWordLinesAllLanguages(anyList(), anyList());
    }

    @Test
    void aNullHeadwordAsksOnlyTheLine() throws Exception {
        when(claude.translateWordLinesAllLanguages(anyList(), anyList()))
                .thenReturn(List.of(lines("a", "A"), lines("b", null)));

        send("", "{\"targetLang\":\"ko\",\"texts\":[\"one\",\"two\"],\"headwords\":[\"uno\",null]}", true)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].headword").value("A"))
                .andExpect(jsonPath("$.lines[1].headword").doesNotExist());
        verify(claude).translateWordLinesAllLanguages(List.of("one", "two"), Arrays.asList("uno", null));
    }

    @Test
    void headwordsOfAnotherLengthAre400() throws Exception {
        send("", "{\"targetLang\":\"ko\",\"texts\":[\"one\",\"two\"],\"headwords\":[\"uno\"]}", true)
                .andExpect(status().isBadRequest());
    }

    @Test
    void withoutHeadwordsTheOldCallIsUsed() throws Exception {
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(List.of(item("moi")));
        send("", "{\"targetLang\":\"ko\",\"texts\":[\"one\"]}", true).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].headword").doesNotExist());
        verify(claude, never()).translateWordLinesAllLanguages(anyList(), anyList());
        assertThat(lines.findAll()).hasSize(7);
    }
}
