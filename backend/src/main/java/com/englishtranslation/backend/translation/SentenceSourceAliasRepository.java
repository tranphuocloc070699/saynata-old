package com.englishtranslation.backend.translation;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SentenceSourceAliasRepository extends JpaRepository<SentenceSourceAlias, String> {

    /**
     * True when a sentence answer of this prompt version named {@code wordMatch} as the English headword of a typed
     * word (TASK-114.5). The version lives on the English row the alias points to. Only then may the word endpoint call Claude.
     */
    @Query("""
            select count(a) > 0 from SentenceSourceAlias a, SentenceTranslation s
            where a.cacheKey = s.cacheKey and a.wordMatch = :wordMatch and s.promptVersion = :promptVersion
            """)
    boolean existsWordMatch(@Param("wordMatch") String wordMatch, @Param("promptVersion") String promptVersion);
}
