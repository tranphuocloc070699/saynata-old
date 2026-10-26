package com.englishtranslation.backend.history;

import java.time.Instant;
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

    /** Words that at least minUsers different people looked up since the given time, most people first. */
    @Query(value = """
            SELECT MIN(text) AS text FROM history_item
            WHERE kind = 'word' AND deleted = FALSE AND at > :since
            GROUP BY text_key
            HAVING COUNT(DISTINCT user_id) >= :minUsers
            ORDER BY COUNT(DISTINCT user_id) DESC, MAX(at) DESC
            LIMIT :limit
            """, nativeQuery = true)
    List<String> hotWords(@Param("since") Instant since, @Param("minUsers") int minUsers, @Param("limit") int limit);

    @Modifying
    @Query("delete from HistoryItem i where i.userId = :userId")
    void deleteAllOf(@Param("userId") Long userId);
}
