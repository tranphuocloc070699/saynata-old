package com.englishtranslation.backend.word;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SimpleWordsTest {

    private final SimpleWords simpleWords = new SimpleWords();

    @Test
    void aCompoundOfTwoListedWordsIsNotHard() {
        assertThat(simpleWords.hardWordsInExample("She is scribbling in her notebook.", "scribbling")).isEmpty();
        assertThat(simpleWords.hardWordsInDefinition("a book you write notes in, like a notebook")).isEmpty();
    }

    @Test
    void aCompoundWithAnUnlistedPartIsStillHard() {
        assertThat(simpleWords.hardWordsInDefinition("to abstain from voting")).containsExactly("abstain");
        assertThat(simpleWords.hardWordsInDefinition("a glorpbook")).containsExactly("glorpbook");
    }
}
