package com.englishtranslation.backend.aipicture;

/** Writes the scene of an AI picture (the admin's wand). The answer is the model's raw text (JSON). */
public interface SceneWriter {

    String write(String system, String userMessage) throws DrawException;
}
