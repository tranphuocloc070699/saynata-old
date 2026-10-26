package com.englishtranslation.backend.lines;

import static com.englishtranslation.backend.lines.LinesFixtures.every;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
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
import com.englishtranslation.backend.translation.TargetLanguage;
import com.englishtranslation.backend.user.User;
import com.englishtranslation.backend.user.UserRepository;
import java.util.ArrayList;
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

/** POST /api/translate-lines with sign-in required: hit, miss, cachedOnly, guest, bad input. Claude is a mock. */
@SpringBootTest(properties = { "app.claude.api-key=test-key", "app.auth.require-sign-in=true" })
@AutoConfigureMockMvc
class TranslateLinesApiTest {

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
        long id = users.findByEmail("lines@example.com")
                .orElseGet(() -> users.save(User.appUser("lines@example.com")))
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

    private static String body(String lang, String... texts) {
        StringBuilder json = new StringBuilder("{\"targetLang\":\"" + lang + "\",\"texts\":[");
        for (int i = 0; i < texts.length; i++) {
            json.append(i > 0 ? "," : "").append("\"").append(texts[i]).append("\"");
        }
        return json.append("]}").toString();
    }

    @Test
    void aMissAsksClaudeOnceForAllMissesAndKeepsTheOrder() throws Exception {
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(every("moi", "hai"));

        send("", body("ko", "one", "two"), true).andExpect(status().isOk())
                .andExpect(jsonPath("$.targetLang").value("ko"))
                .andExpect(jsonPath("$.lines.length()").value(2))
                .andExpect(jsonPath("$.lines[0].text").value("one"))
                .andExpect(jsonPath("$.lines[0].translation").value("moi"))
                .andExpect(jsonPath("$.lines[0].cached").value(false))
                .andExpect(jsonPath("$.lines[1].translation").value("hai"));

        verify(claude, times(1)).translateLinesAllLanguages(List.of("one", "two"));
        assertThat(lines.findAll()).hasSize(14).allMatch(line -> line.getSource().equals("llm"));
    }

    @Test
    void theSecondRequestComesFromTheCacheWithoutAnLlmCall() throws Exception {
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(every("moi"));
        send("", body("ko", "one"), true).andExpect(status().isOk());

        // Same text with other spaces: the same normalized text.
        send("", body("ko", "  one  "), true).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].translation").value("moi"))
                .andExpect(jsonPath("$.lines[0].cached").value(true));

        verify(claude, times(1)).translateLinesAllLanguages(anyList());
    }

    @Test
    void oneCallSavesEveryLanguageAndAnotherLanguageIsCached() throws Exception {
        var item = new java.util.EnumMap<TargetLanguage, String>(TargetLanguage.class);
        item.put(TargetLanguage.VI, "vi line");
        item.put(TargetLanguage.JA, "ja line");
        item.put(TargetLanguage.KO, "ko line");
        item.put(TargetLanguage.ZH, "zh line");
        item.put(TargetLanguage.FR, "fr line");
        item.put(TargetLanguage.ES, "es line");
        item.put(TargetLanguage.DE, "de line");
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(List.of(item));

        send("", body("ko", "one"), true).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].translation").value("ko line"));
        assertThat(lines.findAll()).hasSize(7).allMatch(line -> line.getSource().equals("llm"));

        send("", body("ja", "one"), true).andExpect(jsonPath("$.lines[0].translation").value("ja line"))
                .andExpect(jsonPath("$.lines[0].cached").value(true));
        verify(claude, times(1)).translateLinesAllLanguages(anyList());
    }

    @Test
    void aLanguageTheModelLeftOutIsNotSaved() throws Exception {
        var item = new java.util.EnumMap<TargetLanguage, String>(TargetLanguage.class);
        item.put(TargetLanguage.KO, "ko line");
        item.put(TargetLanguage.JA, "  ");
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(List.of(item));

        send("", body("ja", "one"), true).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].translation").doesNotExist());
        assertThat(lines.findAll()).hasSize(1);
    }

    @Test
    void onlyTheMissesGoToClaude() throws Exception {
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(every("moi"), every("hai"));
        send("", body("vi", "one"), true).andExpect(status().isOk());

        send("", body("vi", "one", "two"), true).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].cached").value(true))
                .andExpect(jsonPath("$.lines[1].cached").value(false))
                .andExpect(jsonPath("$.lines[1].translation").value("hai"));

        verify(claude).translateLinesAllLanguages(List.of("two"));
    }

    @Test
    void cachedOnlyNeverCallsClaudeAndMissesAreNull() throws Exception {
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(every("moi"));
        send("", body("vi", "one"), true).andExpect(status().isOk());

        // A guest may use cachedOnly: it never reaches the gate.
        send("?cachedOnly=true", body("vi", "one", "two"), false).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].translation").value("moi"))
                .andExpect(jsonPath("$.lines[0].cached").value(true))
                .andExpect(jsonPath("$.lines[1].translation").doesNotExist())
                .andExpect(jsonPath("$.lines[1].cached").value(false));

        verify(claude, times(1)).translateLinesAllLanguages(anyList());
    }

    @Test
    void aGuestMissGets401() throws Exception {
        send("", body("vi", "one"), false).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("sign_in_required"));

        verify(claude, never()).translateLinesAllLanguages(anyList());
    }

    @Test
    void aGuestHitNeedsNoSignIn() throws Exception {
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(every("moi"));
        send("", body("vi", "one"), true).andExpect(status().isOk());

        send("", body("vi", "one"), false).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].cached").value(true));
    }

    @Test
    void englishIsRejected() throws Exception {
        send("", body("en", "one"), true).andExpect(status().isBadRequest());
        verify(claude, never()).translateLinesAllLanguages(anyList());
    }

    @Test
    void anUnknownLanguageIsRejected() throws Exception {
        send("", body("xx", "one"), true).andExpect(status().isBadRequest());
    }

    @Test
    void tooManyEmptyOrLongTextsAreRejected() throws Exception {
        String[] twentyOne = new String[21];
        Arrays.fill(twentyOne, "a");
        send("", body("vi", twentyOne), true).andExpect(status().isBadRequest());
        send("", "{\"targetLang\":\"vi\",\"texts\":[]}", true).andExpect(status().isBadRequest());
        send("", body("vi", "   "), true).andExpect(status().isBadRequest());
        send("", body("vi", "a".repeat(501)), true).andExpect(status().isBadRequest());
        send("", "{\"targetLang\":\"vi\"}", true).andExpect(status().isBadRequest());
        verify(claude, never()).translateLinesAllLanguages(anyList());
    }

    @Test
    void twentyTextsAreFine() throws Exception {
        String[] texts = new String[20];
        List<Map<TargetLanguage, String>> answers = new ArrayList<>();
        for (int i = 0; i < 20; i++) {
            texts[i] = "text " + i;
            answers.add(LinesFixtures.item("line " + i));
        }
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(answers);

        send("", body("vi", texts), true).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines.length()").value(20))
                .andExpect(jsonPath("$.lines[19].translation").value("line 19"));
    }

    @Test
    void theSameTextTwiceInOneRequestIsAskedOnce() throws Exception {
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(every("moi"));

        send("", body("vi", "one", "one"), true).andExpect(status().isOk())
                .andExpect(jsonPath("$.lines[0].translation").value("moi"))
                .andExpect(jsonPath("$.lines[1].translation").value("moi"));

        verify(claude).translateLinesAllLanguages(List.of("one"));
    }

    @Test
    void textHashIsSha256OfTheNormalizedText() {
        assertThat(LineTranslationService.normalize("  a \n  b\t c ")).isEqualTo("a b c");
        assertThat(LineTranslationService.hash("abc"))
                .isEqualTo("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    }
}
