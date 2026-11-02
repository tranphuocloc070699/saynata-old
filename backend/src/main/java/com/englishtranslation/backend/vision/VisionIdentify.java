package com.englishtranslation.backend.vision;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/** What the model said about one photo. Only the hash of the photo is kept, never the photo. */
@Entity
@Table(name = "vision_identify")
public class VisionIdentify {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "image_hash", nullable = false, length = 64)
    private String imageHash;

    @Column(name = "prompt_version", nullable = false, length = 20)
    private String promptVersion;

    @Column(name = "label", nullable = false, length = 100)
    private String label;

    @Column(name = "kind", nullable = false, length = 10)
    private String kind;

    @Column(name = "confidence", nullable = false)
    private double confidence;

    @Column(name = "model", nullable = false, length = 80)
    private String model;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected VisionIdentify() {
    }

    public VisionIdentify(String imageHash, String promptVersion, String label, String kind, double confidence,
            String model, Instant createdAt) {
        this.imageHash = imageHash;
        this.promptVersion = promptVersion;
        this.label = label;
        this.kind = kind;
        this.confidence = confidence;
        this.model = model;
        this.createdAt = createdAt;
    }

    public String getLabel() {
        return label;
    }

    public String getKind() {
        return kind;
    }

    public double getConfidence() {
        return confidence;
    }
}
