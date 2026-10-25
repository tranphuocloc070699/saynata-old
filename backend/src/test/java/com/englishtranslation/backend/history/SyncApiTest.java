package com.englishtranslation.backend.history;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.englishtranslation.backend.auth.AccessTokenService;
import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.liked.LikedItemRepository;
import com.englishtranslation.backend.user.User;
import com.englishtranslation.backend.user.UserRepository;
import java.util.stream.IntStream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/** POST /api/sync, GET/PUT /api/me/settings and the new fields of GET /api/me (TASK-93.3). */
@SpringBootTest(properties = "app.claude.api-key=test-key")
@AutoConfigureMockMvc
class SyncApiTest {

    @Autowired
    MockMvc mockMvc;
    @Autowired
    UserRepository users;
    @Autowired
    HistoryItemRepository history;
    @Autowired
    LikedItemRepository liked;
    @Autowired
    AccessTokenService accessTokens;

    @MockitoBean
    ClaudeService claude;

    private String tokenA;
    private String tokenB;

    @BeforeEach
    void setUp() {
        history.deleteAll();
        liked.deleteAll();
        users.deleteAll();
        tokenA = accessTokens.createToken(users.save(User.appUser("sync-a@example.com")).getId());
        tokenB = accessTokens.createToken(users.save(User.appUser("sync-b@example.com")).getId());
    }

    private static String op(String type, String kind, String text, String at) {
        return "{\"type\":\"" + type + "\",\"kind\":\"" + kind + "\",\"text\":\"" + text + "\",\"preview\":\"p\",\"at\":\"" + at + "\"}";
    }

    private static String clear(String at) {
        return "{\"type\":\"history_clear\",\"at\":\"" + at + "\"}";
    }

    private ResultActions sync(String token, long since, String... ops) throws Exception {
        return mockMvc.perform(post("/api/sync").header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"since\":" + since + ",\"ops\":[" + String.join(",", ops) + "]}"));
    }

    private long cursor(ResultActions result) throws Exception {
        String body = result.andReturn().getResponse().getContentAsString();
        return Long.parseLong(body.replaceAll(".*\"cursor\":(\\d+).*", "$1"));
    }

    @Test
    void guestGets401SignInRequired() throws Exception {
        mockMvc.perform(post("/api/sync").contentType(MediaType.APPLICATION_JSON).content("{\"ops\":[]}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("sign_in_required"));
    }

    @Test
    void moreThanTheOpLimitIs400() throws Exception {
        String[] ops = IntStream.range(0, SyncService.MAX_OPS + 1)
                .mapToObj(i -> op("history_add", "word", "w" + i, "2026-01-01T00:00:00Z")).toArray(String[]::new);
        sync(tokenA, 0, ops).andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("too_many_ops"));
    }

    @Test
    void badOpIs400AndNothingIsApplied() throws Exception {
        sync(tokenA, 0, op("history_add", "word", "ok", "2026-01-01T00:00:00Z"),
                op("history_add", "color", "x", "2026-01-01T00:00:00Z")).andExpect(status().isBadRequest());
        sync(tokenA, 0).andExpect(jsonPath("$.changes.history.length()").value(0));
    }

    @Test
    void wordKeyIsLowercasedAndSentenceKeyKeepsCase() throws Exception {
        sync(tokenA, 0, op("history_add", "word", "  Hello  ", "2026-01-01T00:00:01Z"),
                op("history_add", "word", "hello", "2026-01-01T00:00:02Z"),
                op("history_add", "sentence", "Hi there", "2026-01-01T00:00:03Z"),
                op("history_add", "sentence", "hi there", "2026-01-01T00:00:04Z"))
                .andExpect(jsonPath("$.changes.history.length()").value(3));
    }

    @Test
    void newestAtWinsWhateverTheOrderInTheBatch() throws Exception {
        // remove at :05 is newer than the add at :01, even though it is sent first
        sync(tokenA, 0, op("history_remove", "word", "cat", "2026-01-01T00:00:05Z"),
                op("history_add", "word", "cat", "2026-01-01T00:00:01Z"))
                .andExpect(jsonPath("$.changes.history.length()").value(1))
                .andExpect(jsonPath("$.changes.history[0].deleted").value(true));
        // a later add revives it
        sync(tokenA, 0, op("history_add", "word", "cat", "2026-01-01T00:00:09Z"))
                .andExpect(jsonPath("$.changes.history[0].deleted").value(false));
        // an older add from another device loses against it
        sync(tokenA, 0, op("history_add", "word", "cat", "2026-01-01T00:00:02Z"))
                .andExpect(jsonPath("$.changes.history[0].at").value("2026-01-01T00:00:09Z"));
    }

    @Test
    void removeIsATombstoneAnotherDeviceGetsAndSinceFiltersOldChanges() throws Exception {
        long first = cursor(sync(tokenA, 0, op("history_add", "word", "dog", "2026-01-01T00:00:01Z"),
                op("liked_add", "word", "dog", "2026-01-01T00:00:01Z")));
        // device B has the cursor; device A removes both; B asks for what is new
        sync(tokenB, 0); // other account sees nothing
        sync(tokenA, first, op("history_remove", "word", "dog", "2026-01-01T00:00:03Z"),
                op("liked_remove", "word", "dog", "2026-01-01T00:00:03Z"))
                .andExpect(jsonPath("$.changes.history.length()").value(1))
                .andExpect(jsonPath("$.changes.history[0].deleted").value(true))
                .andExpect(jsonPath("$.changes.liked[0].deleted").value(true));
        sync(tokenA, 0).andExpect(jsonPath("$.changes.history[0].text").value("dog"));
        long last = cursor(sync(tokenA, first));
        sync(tokenA, last).andExpect(jsonPath("$.changes.history.length()").value(0))
                .andExpect(jsonPath("$.changes.liked.length()").value(0))
                .andExpect(jsonPath("$.cursor").value(last));
    }

    @Test
    void clearAllTombstonesOlderItemsAndBlocksOlderAddsButNotNewerOnes() throws Exception {
        sync(tokenA, 0, op("history_add", "word", "a", "2026-01-01T00:00:01Z"),
                op("history_add", "word", "b", "2026-01-01T00:00:02Z"),
                op("history_add", "word", "c", "2026-01-01T00:00:20Z"));
        sync(tokenA, 0, clear("2026-01-01T00:00:10Z"),
                op("history_add", "word", "late-old", "2026-01-01T00:00:05Z"))
                .andExpect(jsonPath("$.changes.history[?(@.text=='a')].deleted").value(true))
                .andExpect(jsonPath("$.changes.history[?(@.text=='b')].deleted").value(true))
                .andExpect(jsonPath("$.changes.history[?(@.text=='c')].deleted").value(false))
                .andExpect(jsonPath("$.changes.history[?(@.text=='late-old')].deleted").value(true));
        // a device that was offline adds an old item later: still ignored
        sync(tokenA, 0, op("history_add", "word", "late-old2", "2026-01-01T00:00:06Z"))
                .andExpect(jsonPath("$.changes.history[?(@.text=='late-old2')]").isEmpty());
    }

    @Test
    void historyIsCappedAt1000ByDroppingTheOldest() throws Exception {
        for (int batch = 0; batch < 6; batch++) {
            final int b = batch;
            String[] ops = IntStream.range(0, 190).mapToObj(i -> {
                int n = b * 190 + i; // 1140 items, increasing time
                return op("history_add", "word", "w" + n, String.format("2026-01-01T%02d:%02d:00Z", n / 60, n % 60));
            }).toArray(String[]::new);
            sync(tokenA, 0, ops).andExpect(status().isOk());
        }
        long live = history.countByUserIdAndDeletedFalse(users.findByEmail("sync-a@example.com").orElseThrow().getId());
        org.assertj.core.api.Assertions.assertThat(live).isEqualTo(SyncService.MAX_HISTORY);
        sync(tokenA, 0).andExpect(jsonPath("$.changes.history[?(@.text=='w0')].deleted").value(true))
                .andExpect(jsonPath("$.changes.history[?(@.text=='w1139')].deleted").value(false));
    }

    @Test
    void accountsAreSeparate() throws Exception {
        sync(tokenA, 0, op("history_add", "word", "mine", "2026-01-01T00:00:01Z"));
        sync(tokenB, 0).andExpect(jsonPath("$.changes.history.length()").value(0));
    }

    @Test
    void likedSyncAndTheOldLikedEndpointsSeeTheSameRows() throws Exception {
        sync(tokenA, 0, op("liked_add", "sentence", "Nice day", "2026-01-01T00:00:01Z"));
        mockMvc.perform(get("/api/liked").header("Authorization", "Bearer " + tokenA))
                .andExpect(jsonPath("$.items[0].text").value("Nice day"));
        mockMvc.perform(put("/api/liked").header("Authorization", "Bearer " + tokenA)
                .contentType(MediaType.APPLICATION_JSON).content("{\"kind\":\"word\",\"text\":\"Old Build\",\"preview\":\"x\"}"))
                .andExpect(status().isOk());
        sync(tokenA, 0).andExpect(jsonPath("$.changes.liked.length()").value(2));
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete("/api/liked?kind=word&text=old build")
                .header("Authorization", "Bearer " + tokenA)).andExpect(status().isNoContent());
        sync(tokenA, 0).andExpect(jsonPath("$.changes.liked[?(@.deleted==true)].text").exists());
        mockMvc.perform(get("/api/liked").header("Authorization", "Bearer " + tokenA))
                .andExpect(jsonPath("$.items.length()").value(1));
    }

    @Test
    void settingsHaveDefaultsAndTurningSyncHistoryOffDeletesServerHistory() throws Exception {
        mockMvc.perform(get("/api/me/settings").header("Authorization", "Bearer " + tokenA))
                .andExpect(jsonPath("$.targetLanguage").value("vi"))
                .andExpect(jsonPath("$.showTranslation").value("remember"))
                .andExpect(jsonPath("$.syncHistory").value(true));
        sync(tokenA, 0, op("history_add", "word", "gone", "2026-01-01T00:00:01Z"),
                op("liked_add", "word", "stay", "2026-01-01T00:00:01Z"));
        mockMvc.perform(put("/api/me/settings").header("Authorization", "Bearer " + tokenA)
                .contentType(MediaType.APPLICATION_JSON).content("{\"syncHistory\":false,\"showTranslation\":\"collapsed\"}"))
                .andExpect(jsonPath("$.syncHistory").value(false))
                .andExpect(jsonPath("$.showTranslation").value("collapsed"))
                .andExpect(jsonPath("$.targetLanguage").value("vi"));
        sync(tokenA, 0, op("history_add", "word", "ignored", "2026-01-01T00:00:09Z"))
                .andExpect(jsonPath("$.changes.history.length()").value(0))
                .andExpect(jsonPath("$.changes.liked.length()").value(1));
    }

    @Test
    void settingsRejectBadValuesAndGuestsAreRefused() throws Exception {
        mockMvc.perform(put("/api/me/settings").header("Authorization", "Bearer " + tokenA)
                .contentType(MediaType.APPLICATION_JSON).content("{\"showTranslation\":\"nope\"}"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(get("/api/me/settings")).andExpect(status().is4xxClientError());
    }

    @Test
    void meReturnsTheAccountNumbers() throws Exception {
        sync(tokenA, 0, op("history_add", "word", "x", "2026-01-01T00:00:01Z"),
                op("liked_add", "word", "x", "2026-01-01T00:00:01Z"));
        mockMvc.perform(get("/api/me").header("Authorization", "Bearer " + tokenA))
                .andExpect(jsonPath("$.email").value("sync-a@example.com"))
                .andExpect(jsonPath("$.signInMethod").value("email"))
                .andExpect(jsonPath("$.memberSince").exists())
                .andExpect(jsonPath("$.historyCount").value(1))
                .andExpect(jsonPath("$.likedCount").value(1))
                .andExpect(jsonPath("$.aiUsedToday").value(0))
                .andExpect(jsonPath("$.aiLimitToday").isNumber());
    }
}
