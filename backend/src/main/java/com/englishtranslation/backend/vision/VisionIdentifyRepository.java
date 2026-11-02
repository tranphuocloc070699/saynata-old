package com.englishtranslation.backend.vision;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VisionIdentifyRepository extends JpaRepository<VisionIdentify, Long> {

    Optional<VisionIdentify> findByImageHashAndPromptVersion(String imageHash, String promptVersion);

    boolean existsByLabelAndPromptVersion(String label, String promptVersion);
}
