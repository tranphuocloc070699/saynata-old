package com.englishtranslation.backend.aipicture;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Writes the scene with the Codex CLI and the ChatGPT login (TASK-117), so the wand costs no API money. Runs
 * {@code codex exec --output-last-message <file>} with the same text prompt the Claude call used, and reads the
 * model's last message from that file. Same safety as {@link CodexImageDrawer}: a clean environment, a read-only
 * sandbox, no stdin, and a timeout.
 */
@Component
public class CodexSceneWriter implements SceneWriter {

    private static final Logger log = LoggerFactory.getLogger(CodexSceneWriter.class);
    private static final String ONLY_ANSWER = "\n\nAnswer with the JSON object only. Do not draw a picture and do not"
            + " run any command.";

    private final AiPictureProperties properties;

    public CodexSceneWriter(AiPictureProperties properties) {
        this.properties = properties;
    }

    @Override
    public String write(String system, String userMessage) throws DrawException {
        Path workDir = null;
        Path answerFile = null;
        Path logFile = null;
        try {
            workDir = Files.createTempDirectory("saynata-scene-");
            answerFile = Files.createTempFile("saynata-scene-", ".txt");
            logFile = Files.createTempFile("saynata-scene-", ".log");
            ProcessBuilder builder = new ProcessBuilder(command(properties, answerFile, system + "\n\n" + userMessage
                    + ONLY_ANSWER));
            builder.directory(workDir.toFile());
            Map<String, String> environment = builder.environment();
            environment.clear();
            environment.putAll(CodexImageDrawer.cleanEnvironment(System.getenv(), properties.codexHome()));
            builder.redirectInput(ProcessBuilder.Redirect.from(new File("/dev/null")));
            builder.redirectErrorStream(true);
            builder.redirectOutput(logFile.toFile());

            Process process = builder.start();
            if (!process.waitFor(properties.timeout().toSeconds(), TimeUnit.SECONDS)) {
                process.descendants().forEach(ProcessHandle::destroyForcibly);
                process.destroyForcibly();
                throw new DrawException("Codex took too long (more than " + properties.timeout().toSeconds()
                        + " seconds) while writing the scene. Try again.");
            }
            String answer = Files.readString(answerFile, StandardCharsets.UTF_8).strip();
            if (answer.isEmpty()) {
                String output = Files.readString(logFile, StandardCharsets.UTF_8);
                log.warn("Codex wrote no scene (exit {}): {}", process.exitValue(), output);
                throw new DrawException(CodexImageDrawer.problemText(output, process.exitValue()));
            }
            return answer;
        } catch (IOException e) {
            throw new DrawException("Could not run Codex on the server: " + e.getMessage()
                    + ". Is it installed (AI_PICTURES_ENABLED, doc-11)?", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new DrawException("The server stopped before the scene was written.", e);
        } finally {
            delete(answerFile);
            delete(logFile);
            delete(workDir);
        }
    }

    /** codex exec --skip-git-repo-check --sandbox <sandbox> --output-last-message <file> <prompt>. */
    static List<String> command(AiPictureProperties properties, Path answerFile, String prompt) {
        List<String> command = new ArrayList<>();
        command.add(properties.codexCommand());
        command.add("exec");
        command.add("--skip-git-repo-check");
        command.add("--sandbox");
        command.add(properties.sandbox());
        command.add("--output-last-message");
        command.add(answerFile.toString());
        command.add(prompt);
        return command;
    }

    private static void delete(Path path) {
        if (path == null) {
            return;
        }
        try {
            Files.deleteIfExists(path);
        } catch (IOException | RuntimeException ignored) {
            // a temp file we cannot delete is not worth failing for (a folder with files stays; it is in /tmp)
        }
    }
}
