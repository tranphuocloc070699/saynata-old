package com.englishtranslation.backend.history;

import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** GET /api/words/hot?limit=10: open to guests, never calls Claude, rate limited with the other public reads. */
@RestController
@RequestMapping("/api/words/hot")
public class HotWordsController {

    public record HotWord(String text) {
    }

    public record HotWordsResponse(List<HotWord> words) {
    }

    private final HotWordsService service;

    public HotWordsController(HotWordsService service) {
        this.service = service;
    }

    @GetMapping
    public HotWordsResponse hot(@RequestParam(defaultValue = "10") int limit) {
        return new HotWordsResponse(service.hot(limit).stream().map(HotWord::new).toList());
    }
}
