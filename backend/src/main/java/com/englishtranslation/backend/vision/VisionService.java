package com.englishtranslation.backend.vision;

import com.englishtranslation.backend.claude.ClaudeUsageService;
import com.englishtranslation.backend.claude.Feature;
import com.englishtranslation.backend.claude.GeminiClient;
import com.englishtranslation.backend.common.ApiException;
import com.englishtranslation.backend.limits.ClaudeGate;
import java.io.IOException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.text.Normalizer;
import java.time.Clock;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * POST /api/vision/identify (TASK-121.1): cache first (table vision_identify, key = sha256 of the photo + prompt
 * version), then ClaudeGate, then ONE Gemini call with the photo. A cache hit never reaches the gate. The photo is
 * only in memory for the request; it is never saved.
 */
@Service
public class VisionService {

    private static final Logger log = LoggerFactory.getLogger(VisionService.class);

    static final long MAX_BYTES = 2L * 1024 * 1024;
    private static final Set<String> KINDS = Set.of("object", "dish", "text");
    /** Same letters as GET /api/words/{word}: up to 6 words, so the app can ask for the label. */
    private static final Pattern LABEL = Pattern
            .compile("(?=.{1,64}$)[\\p{L}\\p{N}'-]+( +[\\p{L}\\p{N}'-]+){0,5}");

    static final String SYSTEM = """
            You name the main thing in a photo for an English learner. Answer with JSON only:
            {"label": "...", "kind": "object|dish|text", "confidence": 0.0}
            label: one short, common English noun phrase, lowercase, no article ("teapot", "red bicycle").
            If it is a Vietnamese dish, label is its Vietnamese name with accents (phở, bánh mì) and kind is "dish".
            If the photo is mainly writing, kind is "text" and label is what the writing is ("menu", "street sign").
            Otherwise kind is "object".
            confidence: 0 to 1, how sure you are.""";
    static final String USER = "What is in this photo?";

    private final VisionIdentifyRepository rows;
    private final GeminiClient gemini;
    private final ClaudeGate gate;
    private final ClaudeUsageService usage;
    private final Clock clock;
    private final JsonMapper json;
    private final String promptVersion;

    public VisionService(VisionIdentifyRepository rows, GeminiClient gemini, ClaudeGate gate,
            ClaudeUsageService usage, Clock clock, JsonMapper json,
            @Value("${app.claude.vision-prompt-version:v1}") String promptVersion) {
        this.rows = rows;
        this.gemini = gemini;
        this.gate = gate;
        this.usage = usage;
        this.clock = clock;
        this.json = json;
        this.promptVersion = promptVersion;
    }

    public VisionResponse identify(MultipartFile image) {
        if (image == null || image.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_image", "Send a photo in the part named image.");
        }
        if (image.getSize() > MAX_BYTES) {
            throw tooBig();
        }
        byte[] bytes;
        try {
            bytes = image.getBytes();
        } catch (IOException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_image", "The photo could not be read.");
        }
        if (bytes.length > MAX_BYTES) {
            throw tooBig();
        }
        String mime = mimeOf(bytes);
        if (mime == null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "invalid_image", "The photo must be a JPEG or a PNG.");
        }

        String hash = sha256(bytes);
        Optional<VisionIdentify> saved = rows.findByImageHashAndPromptVersion(hash, promptVersion);
        if (saved.isPresent()) {
            return response(saved.get());
        }

        // Only a new photo gets here. A guest cannot cause a model call.
        gate.beforeNewCall();
        if (!gemini.configured()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "vision_unavailable",
                    "Photo help is not available right now.");
        }
        GeminiClient.Reply reply;
        try {
            reply = gemini.describeImage(SYSTEM, USER, bytes, mime, 500, 0.0);
        } catch (RuntimeException e) {
            log.warn("Vision call failed: {}", e.toString());
            throw new ApiException(HttpStatus.BAD_GATEWAY, "vision_failed", "Could not look at the photo. Try again.");
        }
        usage.record(Feature.VISION, gemini.model(), reply.inputTokens(), reply.outputTokens());

        VisionResponse answer = parse(reply.text());
        VisionIdentify row = new VisionIdentify(hash, promptVersion, answer.label(), answer.kind(),
                answer.confidence(), gemini.model(), clock.instant());
        try {
            rows.saveAndFlush(row);
            return answer;
        } catch (DataIntegrityViolationException e) {
            // The same photo was saved while we waited for the model. Keep the first answer.
            return rows.findByImageHashAndPromptVersion(hash, promptVersion).map(this::response).orElse(answer);
        }
    }

    /** Reads the model's JSON (code fences are removed). A bad label or no JSON is a 502, nothing is saved. */
    VisionResponse parse(String text) {
        try {
            String clean = text == null ? "" : text.strip();
            int start = clean.indexOf('{');
            int end = clean.lastIndexOf('}');
            if (start < 0 || end <= start) {
                throw new IllegalArgumentException("no JSON");
            }
            JsonNode node = json.readTree(clean.substring(start, end + 1));
            String label = cleanLabel(node.path("label").asString(""));
            if (!LABEL.matcher(label).matches()) {
                throw new IllegalArgumentException("bad label");
            }
            String kind = node.path("kind").asString("object").strip().toLowerCase(Locale.ROOT);
            if (!KINDS.contains(kind)) {
                kind = "object";
            }
            double confidence = node.path("confidence").asDouble(0);
            if (Double.isNaN(confidence)) {
                confidence = 0;
            }
            return new VisionResponse(label, kind, Math.max(0, Math.min(1, confidence)));
        } catch (RuntimeException e) {
            log.warn("Could not read the vision answer ({}): {}", e.toString(),
                    text == null ? "" : text.substring(0, Math.min(200, text.length())));
            throw new ApiException(HttpStatus.BAD_GATEWAY, "vision_failed", "Could not look at the photo. Try again.");
        }
    }

    private VisionResponse response(VisionIdentify row) {
        return new VisionResponse(row.getLabel(), row.getKind(), row.getConfidence());
    }

    private static String cleanLabel(String label) {
        String text = Normalizer.normalize(label, Normalizer.Form.NFC).toLowerCase(Locale.ROOT)
                .replaceAll("\\s+", " ").strip();
        return text.replaceAll("^[\"'.\\s]+|[\"'.,!?\\s]+$", "");
    }

    /** "image/jpeg" or "image/png" from the first bytes (the client's content type is not trusted), else null. */
    static String mimeOf(byte[] b) {
        if (b.length > 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8 && (b[2] & 0xFF) == 0xFF) {
            return "image/jpeg";
        }
        if (b.length > 8 && (b[0] & 0xFF) == 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G') {
            return "image/png";
        }
        return null;
    }

    private static ApiException tooBig() {
        return new ApiException(HttpStatus.CONTENT_TOO_LARGE, "file_too_large",
                "That photo is too big. The limit is 2 MB.");
    }

    private static String sha256(byte[] bytes) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
