package com.englishtranslation.backend.aipicture;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/** The wand's scene is written by Codex (TASK-117). A fake shell script stands in for the codex program. */
class CodexSceneWriterTest {

    @TempDir
    Path dir;

    private AiPictureProperties properties(String command, Duration timeout) {
        return new AiPictureProperties(true, 30, command, dir.toString(), "read-only", timeout);
    }

    private String script(String body) throws Exception {
        Path file = dir.resolve("fake-codex.sh");
        Files.writeString(file, "#!/bin/sh\n" + body + "\n");
        file.toFile().setExecutable(true);
        return file.toString();
    }

    @Test
    void commandAsksForOnlyTheLastMessageInAReadOnlySandbox() {
        List<String> command = CodexSceneWriter.command(properties("codex", Duration.ofSeconds(5)),
                Path.of("/tmp/answer.txt"), "PROMPT");

        assertThat(command).containsExactly("codex", "exec", "--skip-git-repo-check", "--sandbox", "read-only",
                "--output-last-message", "/tmp/answer.txt", "PROMPT");
    }

    @Test
    void readsTheLastMessageFromTheOutputFile() throws Exception {
        // $6 is the file after --output-last-message ($1 exec, $2 --skip-git-repo-check, $3 --sandbox, $4 mode, $5 flag)
        String fake = script("echo '{\"method\":\"action\"}' > \"$6\"");

        String answer = new CodexSceneWriter(properties(fake, Duration.ofSeconds(10))).write("system", "user");

        assertThat(answer).isEqualTo("{\"method\":\"action\"}");
    }

    @Test
    void anEmptyAnswerBecomesAPlainDrawException() throws Exception {
        String fake = script("echo 'Not logged in. Please log in.'");

        assertThatThrownBy(() -> new CodexSceneWriter(properties(fake, Duration.ofSeconds(10))).write("s", "u"))
                .isInstanceOf(DrawException.class)
                .hasMessage(CodexImageDrawer.NOT_SIGNED_IN);
    }

    @Test
    void aMissingProgramIsExplained() {
        assertThatThrownBy(() -> new CodexSceneWriter(properties(dir.resolve("nope").toString(),
                Duration.ofSeconds(5))).write("s", "u"))
                .isInstanceOf(DrawException.class)
                .hasMessageContaining("Could not run Codex");
    }
}
