package com.englishtranslation.backend.vision;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/** The camera asks "what is this?" when the phone is unsure (TASK-121.1, doc-5). */
@RestController
@RequestMapping("/api/vision")
public class VisionController {

    private final VisionService service;

    public VisionController(VisionService service) {
        this.service = service;
    }

    /** Multipart form with one part named "image" (JPEG or PNG, at most 2 MB). */
    @PostMapping(value = "/identify", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public VisionResponse identify(@RequestParam(name = "image", required = false) MultipartFile image) {
        return service.identify(image);
    }
}
