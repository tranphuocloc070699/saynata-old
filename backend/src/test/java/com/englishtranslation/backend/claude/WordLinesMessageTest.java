package com.englishtranslation.backend.claude;

import static org.assertj.core.api.Assertions.assertThat;

import com.englishtranslation.backend.translation.TargetLanguage;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.Test;

/** The message and answer of the word-lines call (TASK-106.8). No model is called. */
class WordLinesMessageTest {

    @Test
    void anItemWithoutAHeadwordHasNoHeadwordTag() {
        String message = ClaudeService.wordLinesMessage(List.of("money <place>", "two"), Arrays.asList("bank", null));

        assertThat(message).isEqualTo("""
                <items>
                <item id="1"><headword>bank</headword><text>money &lt;place&gt;</text></item>
                <item id="2"><text>two</text></item>
                </items>""");
    }

    @Test
    void theAnswerSplitsLinesAndHeadwordsAndDropsBlanks() {
        WordLinesAnswer answer = ClaudeService.parseJson("""
                {"items":[{"ja":"お金を預ける所","jaHeadword":"銀行","ko":"돈","koHeadword":" "}]}""",
                WordLinesAnswer.class);

        WordLinesAnswer.Lines lines = answer.items().get(0).toLines();
        assertThat(lines.lines()).containsEntry(TargetLanguage.JA, "お金を預ける所").containsKey(TargetLanguage.KO);
        assertThat(lines.headwords()).containsOnlyKeys(TargetLanguage.JA).containsEntry(TargetLanguage.JA, "銀行");
    }
}
