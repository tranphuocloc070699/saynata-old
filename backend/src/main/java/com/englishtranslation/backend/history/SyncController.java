package com.englishtranslation.backend.history;

import com.englishtranslation.backend.common.ApiException;
import com.englishtranslation.backend.history.SyncModels.SyncRequest;
import com.englishtranslation.backend.history.SyncModels.SyncResponse;
import com.englishtranslation.backend.limits.CallerContext;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** POST /api/sync (TASK-93.3, doc-22). A guest gets 401 sign_in_required, like /api/liked. */
@RestController
@RequestMapping("/api/sync")
public class SyncController {

    private final SyncService service;

    public SyncController(SyncService service) {
        this.service = service;
    }

    @PostMapping
    public SyncResponse sync(@RequestBody SyncRequest request) {
        long userId = CallerContext.userId().orElseThrow(() ->
                new ApiException(HttpStatus.UNAUTHORIZED, "sign_in_required", "Sign in to sync History and Liked."));
        return service.sync(userId, request);
    }
}
