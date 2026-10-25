package com.englishtranslation.backend.history;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface HistoryItemRepository extends JpaRepository<HistoryItem, Long> {

    Optional<HistoryItem> findByUserIdAndKindAndTextKey(Long userId, String kind, String textKey);

    List<HistoryItem> findByUserIdAndChangeSeqGreaterThanOrderByChangeSeqAsc(Long userId, long since);

    List<HistoryItem> findByUserIdAndDeletedFalseOrderByAtAscIdAsc(Long userId);

    long countByUserIdAndDeletedFalse(Long userId);

    @Modifying
    @Query("delete from HistoryItem i where i.userId = :userId")
    void deleteAllOf(@Param("userId") Long userId);
}
