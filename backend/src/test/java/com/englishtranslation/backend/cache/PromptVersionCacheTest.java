package com.englishtranslation.backend.cache;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.any;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.englishtranslation.backend.claude.LlmProperties;
import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.translation.Explanation;
import com.englishtranslation.backend.translation.SentenceTranslationRepository;
import com.englishtranslation.backend.translation.TargetLanguage;
import com.englishtranslation.backend.translation.TranslationService;
import com.englishtranslation.backend.word.EnglishWords;
import com.englishtranslation.backend.word.IpaDictionary;
import com.englishtranslation.backend.word.SimpleWords;
import com.englishtranslation.backend.word.WordEntry;
import com.englishtranslation.backend.word.WordLookupRepository;
import com.englishtranslation.backend.word.WordService;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import tools.jackson.databind.json.JsonMapper;

/** Sentences and words have their own prompt version, so bumping one keeps the other cache. */
@SpringBootTest(properties = "app.claude.api-key=test-key")
class PromptVersionCacheTest {

    @Autowired
    SentenceTranslationRepository sentences;

    @Autowired
    WordLookupRepository words;

    @Autowired
    JsonMapper jsonMapper;

    @MockitoBean
    ClaudeService claude;

    private final Explanation explanation = new Explanation("A greeting.", List.of(), "Xin chào");
    private final WordEntry entry = new WordEntry(List.of());

    @BeforeEach
    void setUp() {
        sentences.deleteAll();
        words.deleteAll();
        when(claude.explainSentence(eq("hello"), any())).thenReturn(explanation);
        when(claude.describeWord("hello")).thenReturn(entry);
    }

    private LlmProperties versions(String sentence, String word) {
        return new LlmProperties("test-key", "model", sentence, word);
    }

    private TranslationService sentenceService(LlmProperties properties) {
        return new TranslationService(sentences, org.mockito.Mockito.mock(com.englishtranslation.backend.translation.SentenceSourceAliasRepository.class), claude, properties, jsonMapper, new com.englishtranslation.backend.translation.PersonalTextDetector(),
                org.mockito.Mockito.mock(com.englishtranslation.backend.limits.ClaudeGate.class),
                org.mockito.Mockito.mock(com.englishtranslation.backend.lines.LineTranslationService.class), new EnglishWords());
    }

    private WordService wordService(LlmProperties properties) {
        return new WordService(words, claude, properties, jsonMapper, new EnglishWords(), new IpaDictionary(),
                new SimpleWords(), org.mockito.Mockito.mock(com.englishtranslation.backend.media.BackendWordMediaService.class),
                org.mockito.Mockito.mock(com.englishtranslation.backend.media.SenseMediaReader.class),
                org.mockito.Mockito.mock(com.englishtranslation.backend.dictionary.DictionaryWordRepository.class),
                new com.englishtranslation.backend.dictionary.BundledEntryReader(jsonMapper),
                org.mockito.Mockito.mock(com.englishtranslation.backend.limits.ClaudeGate.class),
                org.mockito.Mockito.mock(com.englishtranslation.backend.translation.SentenceSourceAliasRepository.class),
                org.mockito.Mockito.mock(com.englishtranslation.backend.word.WordForms.class),
                org.mockito.Mockito.mock(com.englishtranslation.backend.term.TermService.class),
                org.mockito.Mockito.mock(com.englishtranslation.backend.vision.VisionLabels.class));
    }

    @Test
    void bumpingTheSentenceVersionKeepsCachedWords() {
        wordService(versions("s1", "w1")).lookUp("hello");

        boolean wordStillCached = wordService(versions("s2", "w1")).lookUp("hello").cached();

        assertThat(wordStillCached).isTrue();
        verify(claude, times(1)).describeWord("hello");
    }

    @Test
    void bumpingTheWordVersionKeepsCachedSentences() {
        sentenceService(versions("s1", "w1")).translate("hello", TargetLanguage.VI);

        boolean sentenceStillCached = sentenceService(versions("s1", "w2")).translate("hello", TargetLanguage.VI).cached();

        assertThat(sentenceStillCached).isTrue();
        verify(claude, times(1)).explainSentence(eq("hello"), any());
    }

    @Test
    void bumpingAVersionMissesItsOwnCache() {
        sentenceService(versions("s1", "w1")).translate("hello", TargetLanguage.VI);
        wordService(versions("s1", "w1")).lookUp("hello");

        assertThat(sentenceService(versions("s2", "w1")).translate("hello", TargetLanguage.VI).cached()).isFalse();
        assertThat(wordService(versions("s1", "w2")).lookUp("hello").cached()).isFalse();
    }
}
