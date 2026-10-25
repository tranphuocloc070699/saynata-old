package com.englishtranslation.backend.history;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.englishtranslation.backend.claude.ClaudeService;
import com.englishtranslation.backend.user.User;
import com.englishtranslation.backend.user.UserRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/** GET /api/words/hot: words that several people looked up lately. */
@SpringBootTest(properties = "app.claude.api-key=test-key")
@AutoConfigureMockMvc
class HotWordsTest {

    @Autowired
    MockMvc mockMvc;
    @Autowired
    UserRepository users;
    @Autowired
    HistoryItemRepository history;
    @Autowired
    HotWordsService service;

    @MockitoBean
    ClaudeService claude;

    private Long a;
    private Long b;
    private Long c;
    private long seq;

    @BeforeEach
    void setUp() {
        history.deleteAll();
        users.deleteAll();
        a = users.save(User.appUser("hot-a@example.com")).getId();
        b = users.save(User.appUser("hot-b@example.com")).getId();
        c = users.save(User.appUser("hot-c@example.com")).getId();
        service.forget();
    }

    private void look(Long user, String kind, String key, Instant at, boolean deleted) {
        history.save(newItem(user, kind, key, at, deleted));
    }

    private HistoryItem newItem(Long user, String kind, String key, Instant at, boolean deleted) {
        HistoryItem item = new HistoryItem(user, kind, key);
        item.apply(key, "p", null, at, deleted, ++seq);
        return item;
    }

    private void word(Long user, String key) {
        look(user, "word", key, Instant.now(), false);
    }

    @Test
    void rankedByDistinctUsersAndGuestsCanCallIt() throws Exception {
        word(a, "run");
        word(b, "run");
        word(c, "run");
        word(a, "give up");
        word(b, "give up");
        mockMvc.perform(get("/api/words/hot?limit=10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.words.length()").value(2))
                .andExpect(jsonPath("$.words[0].text").value("run"))
                .andExpect(jsonPath("$.words[1].text").value("give up"));
    }

    @Test
    void aWordOfOnePersonIsNotShown() throws Exception {
        word(a, "secret");
        mockMvc.perform(get("/api/words/hot")).andExpect(jsonPath("$.words.length()").value(0));
    }

    @Test
    void sentencesDeletedAndOldRowsAreLeftOut() throws Exception {
        look(a, "sentence", "Hold on.", Instant.now(), false);
        look(b, "sentence", "Hold on.", Instant.now(), false);
        look(a, "word", "gone", Instant.now(), true);
        look(b, "word", "gone", Instant.now(), true);
        Instant old = Instant.now().minus(20, ChronoUnit.DAYS);
        look(a, "word", "ancient", old, false);
        look(b, "word", "ancient", old, false);
        mockMvc.perform(get("/api/words/hot")).andExpect(jsonPath("$.words.length()").value(0));
    }

    @Test
    void theLimitCutsTheList() throws Exception {
        for (String w : new String[] {"one", "two", "three"}) {
            word(a, w);
            word(b, w);
        }
        mockMvc.perform(get("/api/words/hot?limit=2")).andExpect(jsonPath("$.words.length()").value(2));
    }
}
