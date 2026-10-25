package com.englishtranslation.backend.translation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.englishtranslation.backend.cache.CacheKeys;
import com.englishtranslation.backend.claude.ClaudeProperties;
import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.claude.NotEnglishException;
import com.englishtranslation.backend.lines.LineTranslationRepository;
import com.englishtranslation.backend.lines.LinesFixtures;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import tools.jackson.databind.json.JsonMapper;

/**
 * TASK-114.1: text typed in another language gets the natural English version first. The English part is saved once,
 * under the key of the English version; the typed text points to it with an alias. Claude is a mock.
 */
@SpringBootTest(properties = { "app.claude.api-key=test-key", "app.auth.require-sign-in=false" })
class OtherLanguageSentenceTest {

    private static final String SAD_TODAY = "Hôm nay tôi buồn";
    private static final String SAD_TODAY_OTHER_WORDS = "Hôm nay tao thấy buồn quá";

    @Autowired
    TranslationService service;
    @Autowired
    SentenceTranslationRepository sentences;
    @Autowired
    SentenceSourceAliasRepository aliases;
    @Autowired
    LineTranslationRepository lines;
    @Autowired
    ClaudeProperties properties;
    @Autowired
    JsonMapper jsonMapper;

    @MockitoBean
    ClaudeService claude;

    @BeforeEach
    void cleanDatabase() {
        aliases.deleteAll();
        sentences.deleteAll();
        lines.deleteAll();
    }

    private static Explanation vietnameseSentence() {
        return new Explanation("I feel sad today.", "vi", null, "The person feels unhappy today.", List.of(), null, null,
                "");
    }

    @Test
    void vietnameseSentenceAnswersWithTheEnglishVersionFirstAndKeepsTheTypedText() {
        when(claude.explainSentence(SAD_TODAY)).thenReturn(vietnameseSentence());
        when(claude.translateLinesAllLanguages(List.of(SAD_TODAY))).thenReturn(LinesFixtures.every("Hôm nay tôi buồn"));

        TranslationResponse response = service.translate(SAD_TODAY, TargetLanguage.JA);

        assertThat(response.text()).isEqualTo(SAD_TODAY);
        assertThat(response.explanation().english()).isEqualTo("I feel sad today.");
        assertThat(response.explanation().sourceLang()).isEqualTo("vi");
        assertThat(response.explanation().wordMatch()).isNull();
        assertThat(response.explanation().meaning()).isEqualTo("The person feels unhappy today.");
        // The language line is built from the typed text.
        verify(claude).translateLinesAllLanguages(List.of(SAD_TODAY));
    }

    @Test
    void theJsonHasEnglishAndSourceLangFirstAndEnglishInputIsUnchanged() {
        when(claude.explainSentence(SAD_TODAY)).thenReturn(vietnameseSentence());
        when(claude.explainSentence("Hello there")).thenReturn(new Explanation("A hello.", List.of(), ""));
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(LinesFixtures.every("x"));

        String vietnamese = jsonMapper.writeValueAsString(service.translate(SAD_TODAY, TargetLanguage.VI));
        String english = jsonMapper.writeValueAsString(service.translate("Hello there", TargetLanguage.VI));

        assertThat(vietnamese).contains("\"explanation\":{\"english\":\"I feel sad today.\",\"sourceLang\":\"vi\","
                + "\"meaning\":\"The person feels unhappy today.\",\"words\":[],\"better\":null,\"betterWhy\":null,"
                + "\"translation\":\"" + SAD_TODAY + "\"}");
        assertThat(english).contains("\"explanation\":{\"meaning\":\"A hello.\"")
                .doesNotContain("english", "sourceLang", "wordMatch");
    }

    @Test
    void japaneseSentenceIsAnsweredTheSameWay() {
        String typed = "ありがとうございます";
        when(claude.explainSentence(typed)).thenReturn(new Explanation("Thank you very much.", "ja", null,
                "The person says thanks politely.", List.of(), null, null, ""));
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(LinesFixtures.every("Cảm ơn"));

        TranslationResponse response = service.translate(typed, TargetLanguage.VI);

        assertThat(response.explanation().english()).isEqualTo("Thank you very much.");
        assertThat(response.explanation().sourceLang()).isEqualTo("ja");
        assertThat(response.explanation().translation()).isEqualTo("Cảm ơn");
    }

    @Test
    void singleWordWithAMatchReturnsTheWordMatch() {
        when(claude.explainSentence("buồn")).thenReturn(new Explanation("sad", "vi", "sad", "Feeling unhappy.",
                List.of(), null, null, ""));

        TranslationResponse response = service.translate("buồn", TargetLanguage.VI);

        assertThat(response.explanation().wordMatch()).isEqualTo("sad");
        assertThat(response.explanation().english()).isEqualTo("sad");
        // The target language is Vietnamese and the text is Vietnamese: no line call is needed.
        assertThat(response.explanation().translation()).isEqualTo("buồn");
        verify(claude, never()).translateLinesAllLanguages(anyList());
    }

    @Test
    void theWordMatchComesBackFromTheCacheToo() {
        when(claude.explainSentence("buồn")).thenReturn(new Explanation("sad", "vi", "sad", "Feeling unhappy.",
                List.of(), null, null, ""));

        service.translate("buồn", TargetLanguage.VI);
        TranslationResponse again = service.translate("buồn", TargetLanguage.VI);

        assertThat(again.cached()).isTrue();
        assertThat(again.explanation().wordMatch()).isEqualTo("sad");
        assertThat(again.explanation().sourceLang()).isEqualTo("vi");
        verify(claude, times(1)).explainSentence(anyString());
    }

    @Test
    void singleWordWithoutAMatchHasNoWordMatchAndTheSentenceResultIsReturned() {
        String typed = "nhớ nhà";
        when(claude.explainSentence(typed)).thenReturn(new Explanation("I miss home.", "vi", null,
                "The person wants to be home.", List.of(), null, null, ""));
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(LinesFixtures.every("x"));

        TranslationResponse response = service.translate(typed, TargetLanguage.JA);

        assertThat(response.explanation().wordMatch()).isNull();
        assertThat(response.explanation().english()).isEqualTo("I miss home.");
        assertThat(response.explanation().meaning()).isEqualTo("The person wants to be home.");
    }

    @Test
    void codeAndGibberishAreRejectedAndNothingIsCached() {
        when(claude.explainSentence("asdkj qwe zzxq")).thenThrow(new NotEnglishException());

        assertThatThrownBy(() -> service.translate("asdkj qwe zzxq", TargetLanguage.VI))
                .isInstanceOf(NotEnglishException.class)
                .hasMessage("This doesn't look like English. Type an English word or sentence.");

        assertThat(sentences.count()).isZero();
        assertThat(aliases.count()).isZero();
        assertThat(lines.count()).isZero();
    }

    @Test
    void twoWordingsWithTheSameEnglishShareOneEnglishPart() {
        when(claude.explainSentence(SAD_TODAY)).thenReturn(vietnameseSentence());
        // The second wording gets the same English back, but its own summary text must not replace the saved one.
        when(claude.explainSentence(SAD_TODAY_OTHER_WORDS)).thenReturn(new Explanation("I feel sad today.", "vi", null,
                "Someone is very sad now.", List.of(), null, null, ""));
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(LinesFixtures.every("x"));

        TranslationResponse first = service.translate(SAD_TODAY, TargetLanguage.JA);
        TranslationResponse second = service.translate(SAD_TODAY_OTHER_WORDS, TargetLanguage.JA);

        assertThat(sentences.count()).isEqualTo(1);
        assertThat(aliases.count()).isEqualTo(2);
        assertThat(second.explanation().meaning()).isEqualTo(first.explanation().meaning());
        assertThat(second.explanation().english()).isEqualTo("I feel sad today.");
        assertThat(second.text()).isEqualTo(SAD_TODAY_OTHER_WORDS);
        assertThat(sentences.findByCacheKey(CacheKeys.sentenceKey(properties.sentencePromptVersion(),
                "I feel sad today."))).isPresent();
    }

    @Test
    void theSameTypedTextAgainIsAHitWithoutCallingClaude() {
        when(claude.explainSentence(SAD_TODAY)).thenReturn(vietnameseSentence());
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(LinesFixtures.every("x"));

        service.translate(SAD_TODAY, TargetLanguage.JA);
        TranslationResponse again = service.translate("  Hôm nay   tôi buồn ", TargetLanguage.JA);

        assertThat(again.cached()).isTrue();
        assertThat(again.explanation().english()).isEqualTo("I feel sad today.");
        assertThat(again.explanation().sourceLang()).isEqualTo("vi");
        verify(claude, times(1)).explainSentence(anyString());
    }

    @Test
    void anEnglishLearnerTypingTheEnglishVersionGetsNoLanguageFields() {
        when(claude.explainSentence(SAD_TODAY)).thenReturn(vietnameseSentence());
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(LinesFixtures.every("x"));
        service.translate(SAD_TODAY, TargetLanguage.JA);

        TranslationResponse english = service.translate("I feel sad today.", TargetLanguage.JA);

        assertThat(english.cached()).isTrue();
        assertThat(english.explanation().english()).isNull();
        assertThat(english.explanation().sourceLang()).isNull();
        assertThat(english.explanation().wordMatch()).isNull();
    }

    @Test
    void cachedOnlyFindsATypedTextBySavedAliasButNeverAsksClaude() {
        when(claude.explainSentence(SAD_TODAY)).thenReturn(vietnameseSentence());
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(LinesFixtures.every("x"));
        service.translate(SAD_TODAY, TargetLanguage.JA);

        TranslationResponse hit = service.translate(SAD_TODAY, TargetLanguage.JA, true);

        assertThat(hit.explanation().english()).isEqualTo("I feel sad today.");
        assertThatThrownBy(() -> service.translate("Một câu khác", TargetLanguage.JA, true))
                .isInstanceOf(com.englishtranslation.backend.cache.NotCachedException.class);
        verify(claude, times(1)).explainSentence(anyString());
    }

    @Test
    void streamingGivesTheMeaningEventsAndEnglishFieldsInTheDonePayload() {
        when(claude.explainSentenceStreaming(eq(SAD_TODAY), any())).thenAnswer(call -> {
            java.util.function.Consumer<String> onText = call.getArgument(1);
            onText.accept("{\"sourceLang\":\"vi\",\"english\":\"I feel sad today.\",\"wordMatch\":\"\",");
            onText.accept("\"summary\":\"The person feels unhappy today.\",\"better\":\"\"}");
            return vietnameseSentence();
        });
        when(claude.translateLinesAllLanguages(anyList())).thenReturn(LinesFixtures.every("x"));

        List<String> meanings = new java.util.ArrayList<>();
        TranslationResponse done = service.translateStreaming(SAD_TODAY, TargetLanguage.JA, meanings::add);

        // The meaning events carry the summary of the English version, not the English text or the language.
        assertThat(meanings).containsExactly("The person feels unhappy today.");
        assertThat(done.explanation().english()).isEqualTo("I feel sad today.");
        assertThat(done.explanation().sourceLang()).isEqualTo("vi");
        assertThat(jsonMapper.writeValueAsString(done)).contains("\"english\":\"I feel sad today.\"")
                .contains("\"sourceLang\":\"vi\"");
    }
}
