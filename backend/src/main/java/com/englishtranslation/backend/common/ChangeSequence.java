package com.englishtranslation.backend.common;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.stereotype.Component;

/**
 * The next change number of the sync (TASK-93.3). History and liked rows take one from here every time they change;
 * a client's cursor is the biggest number it has seen, so it asks only for what is newer.
 */
@Component
public class ChangeSequence {

    @PersistenceContext
    private EntityManager entityManager;

    public long next() {
        return ((Number) entityManager.createNativeQuery("select nextval('sync_change_seq')").getSingleResult()).longValue();
    }
}
