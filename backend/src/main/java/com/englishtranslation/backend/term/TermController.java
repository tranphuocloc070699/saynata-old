package com.englishtranslation.backend.term;

import jakarta.validation.constraints.Pattern;
import java.time.Duration;
import java.util.List;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * TASK-119.6: only the terms of a text, for an app that answered the word itself (a bundled word on the phone never
 * asks GET /api/words). Public, no LLM, no sign-in. Terms change only by an import, so a day of caching is fine.
 */
@RestController
@RequestMapping("/api/terms")
public class TermController {

    static final Duration MAX_AGE = Duration.ofDays(1);

    private final TermService terms;

    public TermController(TermService terms) {
        this.terms = terms;
    }

    /** The reply: the text as asked, and its terms (at most 3, most popular first; empty when none). */
    public record TermsResponse(String text, List<Term> terms) {
    }

    /** Same text rule as GET /api/words/{word}: letters, digits, ' and -, dots inside a word, up to 6 words. */
    @GetMapping("/{text}")
    public ResponseEntity<TermsResponse> terms(
            @PathVariable @Pattern(regexp = "(?=.{1,64}$)[\\p{L}\\p{N}'-]+(\\.[\\p{L}\\p{N}'-]+)*( +[\\p{L}\\p{N}'-]+(\\.[\\p{L}\\p{N}'-]+)*){0,5}") String text) {
        return ResponseEntity.ok()
                .cacheControl(CacheControl.maxAge(MAX_AGE).cachePublic())
                .body(new TermsResponse(text, terms.find(text)));
    }
}
