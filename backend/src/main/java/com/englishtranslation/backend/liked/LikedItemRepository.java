package com.englishtranslation.backend.liked;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LikedItemRepository extends JpaRepository<LikedItem, Long> {

    List<LikedItem> findByUserIdAndDeletedFalseOrderByAtDescIdDesc(Long userId);

    List<LikedItem> findByUserIdAndChangeSeqGreaterThanOrderByChangeSeqAsc(Long userId, long since);

    long countByUserIdAndDeletedFalse(Long userId);

    Optional<LikedItem> findByUserIdAndKindAndTextKey(Long userId, String kind, String textKey);

    long countByUserId(Long userId);

}
