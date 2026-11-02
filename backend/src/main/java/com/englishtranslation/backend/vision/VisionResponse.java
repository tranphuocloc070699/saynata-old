package com.englishtranslation.backend.vision;

/** The answer of POST /api/vision/identify. {@code kind} is "object", "dish" or "text"; {@code confidence} is 0..1. */
public record VisionResponse(String label, String kind, double confidence) {
}
