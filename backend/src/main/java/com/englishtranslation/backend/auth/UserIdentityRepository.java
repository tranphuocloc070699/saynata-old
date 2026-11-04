package com.englishtranslation.backend.auth;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserIdentityRepository extends JpaRepository<UserIdentity, Long> {

    Optional<UserIdentity> findByProviderAndSubject(SocialProvider provider, String subject);

    Optional<UserIdentity> findFirstByUserIdOrderByCreatedAtAsc(Long userId);

    List<UserIdentity> findAllByUserId(Long userId);
}
