package com.englishtranslation.backend.auth;

import java.time.Instant;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /** Marks one token as used. Returns 1 for the one request that did it, 0 if it was already revoked. */
    @Transactional
    @Modifying
    @Query("update RefreshToken t set t.revokedAt = :now where t.id = :id and t.revokedAt is null")
    int revoke(@Param("id") Long id, @Param("now") Instant now);

    /** Like {@link #revoke}, for a refresh: also notes that the token was swapped for a new pair. */
    @Transactional
    @Modifying
    @Query("update RefreshToken t set t.revokedAt = :now, t.rotatedAt = :now where t.id = :id and t.revokedAt is null")
    int rotate(@Param("id") Long id, @Param("now") Instant now);

    @Transactional
    @Modifying
    /** Ends every session of the user. Also clears rotatedAt, so no old token gets the reuse grace afterwards. */
    @Query("update RefreshToken t set t.revokedAt = coalesce(t.revokedAt, :now), t.rotatedAt = null "
            + "where t.userId = :userId")
    int revokeAllOf(@Param("userId") Long userId, @Param("now") Instant now);

    @Transactional
    @Modifying
    @Query("delete from RefreshToken t where t.userId = :userId")
    int deleteAllOf(@Param("userId") Long userId);

    /** Housekeeping: tokens that expired a while ago are of no use to anyone. */
    @Transactional
    @Modifying
    @Query("delete from RefreshToken t where t.expiresAt < :before")
    int deleteExpiredBefore(@Param("before") Instant before);
}
