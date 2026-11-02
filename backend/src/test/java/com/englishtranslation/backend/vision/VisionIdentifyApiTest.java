package com.englishtranslation.backend.vision;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.englishtranslation.backend.auth.AccessTokenService;
import com.englishtranslation.backend.claude.ClaudeUsage;
import com.englishtranslation.backend.claude.ClaudeUsageRepository;
import com.englishtranslation.backend.claude.Feature;
import com.englishtranslation.backend.claude.GeminiClient;
import com.englishtranslation.backend.user.User;
import com.englishtranslation.backend.user.UserRepository;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/** POST /api/vision/identify with sign-in required. Gemini is a mock: nothing is paid, no photo leaves the test. */
@SpringBootTest(properties = { "app.claude.api-key=test-key", "app.auth.require-sign-in=true" })
@AutoConfigureMockMvc
class VisionIdentifyApiTest {

    @Autowired
    MockMvc mockMvc;
    @Autowired
    VisionIdentifyRepository rows;
    @Autowired
    ClaudeUsageRepository usageRows;
    @Autowired
    AccessTokenService accessTokens;
    @Autowired
    UserRepository users;

    @MockitoBean
    GeminiClient gemini;

    private String token;

    @BeforeEach
    void setUp() {
        rows.deleteAll();
        usageRows.deleteAll();
        when(gemini.configured()).thenReturn(true);
        when(gemini.model()).thenReturn("gemini-test");
        long id = users.findByEmail("vision@example.com")
                .orElseGet(() -> users.save(User.appUser("vision@example.com"))).getId();
        token = accessTokens.createToken(id);
    }

    static byte[] jpeg(int size, int seed) {
        byte[] bytes = new byte[size];
        Arrays.fill(bytes, (byte) seed);
        bytes[0] = (byte) 0xFF;
        bytes[1] = (byte) 0xD8;
        bytes[2] = (byte) 0xFF;
        bytes[3] = (byte) 0xE0;
        return bytes;
    }

    private ResultActions send(byte[] image, boolean signedIn) throws Exception {
        var request = multipart("/api/vision/identify")
                .file(new MockMultipartFile("image", "p.jpg", "image/jpeg", image));
        if (signedIn) {
            request.header("Authorization", "Bearer " + token);
        }
        return mockMvc.perform(request);
    }

    private void geminiSays(String text) {
        when(gemini.describeImage(anyString(), anyString(), any(byte[].class), anyString(), anyLong(), any()))
                .thenReturn(new GeminiClient.Reply(text, 1200, 20));
    }

    private void verifyGeminiNeverCalled() {
        verify(gemini, never()).describeImage(anyString(), anyString(), any(byte[].class), anyString(), anyLong(),
                any());
    }

    @Test
    void aSignedInUserGetsLabelKindAndConfidence() throws Exception {
        geminiSays("{\"label\":\"Teapot\",\"kind\":\"object\",\"confidence\":0.93}");

        send(jpeg(100, 1), true).andExpect(status().isOk())
                .andExpect(jsonPath("$.label").value("teapot"))
                .andExpect(jsonPath("$.kind").value("object"))
                .andExpect(jsonPath("$.confidence").value(0.93));

        List<ClaudeUsage> usage = usageRows.findAll();
        assertThat(usage).hasSize(1);
        assertThat(usage.get(0).getFeature()).isEqualTo(Feature.VISION);
        assertThat(rows.count()).isEqualTo(1);
    }

    @Test
    void aGuestGets401SignInRequired() throws Exception {
        send(jpeg(100, 2), false).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("sign_in_required"));

        verifyGeminiNeverCalled();
        assertThat(rows.count()).isZero();
    }

    @Test
    void aPhotoOver2MbIsRefused() throws Exception {
        send(jpeg(2 * 1024 * 1024 + 1, 3), true).andExpect(status().isContentTooLarge())
                .andExpect(jsonPath("$.code").value("file_too_large"));

        verifyGeminiNeverCalled();
    }

    @Test
    void somethingThatIsNotAJpegOrPngIsRefused() throws Exception {
        send("hello, I am not a photo".getBytes(), true).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_image"));
    }

    @Test
    void aMissingImagePartIsRefused() throws Exception {
        mockMvc.perform(multipart("/api/vision/identify").header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("invalid_image"));
    }

    @Test
    void theSamePhotoCallsGeminiOnceAndAGuestCanReadTheSavedAnswer() throws Exception {
        geminiSays("{\"label\":\"phở\",\"kind\":\"dish\",\"confidence\":0.8}");
        byte[] photo = jpeg(500, 4);

        send(photo, true).andExpect(status().isOk()).andExpect(jsonPath("$.label").value("phở"));
        // The second request is a cache hit: no model call, no gate (so even a guest gets it), no new usage row.
        send(photo, false).andExpect(status().isOk()).andExpect(jsonPath("$.kind").value("dish"));

        verify(gemini, times(1)).describeImage(anyString(), anyString(), any(byte[].class), eq("image/jpeg"),
                anyLong(), any());
        assertThat(usageRows.count()).isEqualTo(1);
        assertThat(rows.count()).isEqualTo(1);
    }

    @Test
    void confidenceIsClampedAndAnUnknownKindBecomesObject() throws Exception {
        geminiSays("```json\n{\"label\":\"a cup.\",\"kind\":\"drink\",\"confidence\":7}\n```");

        send(jpeg(100, 5), true).andExpect(status().isOk())
                .andExpect(jsonPath("$.label").value("a cup"))
                .andExpect(jsonPath("$.kind").value("object"))
                .andExpect(jsonPath("$.confidence").value(1.0));
    }

    @Test
    void anAnswerThatIsNotJsonIs502AndNothingIsSaved() throws Exception {
        geminiSays("I think it is a cat.");

        send(jpeg(100, 6), true).andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.code").value("vision_failed"));

        assertThat(rows.count()).isZero();
    }

    @Test
    void aFailingModelCallIs502() throws Exception {
        when(gemini.describeImage(anyString(), anyString(), any(byte[].class), anyString(), anyLong(), any()))
                .thenThrow(new IllegalStateException("Gemini answered HTTP 500"));

        send(jpeg(100, 7), true).andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.code").value("vision_failed"));
    }
}
