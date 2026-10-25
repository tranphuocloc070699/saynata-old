package com.englishtranslation.backend.history;

import com.englishtranslation.backend.history.SettingsService.SettingsView;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** GET / PUT /api/me/settings. SecurityConfig requires the USER role for /api/me/**. */
@RestController
@RequestMapping("/api/me/settings")
public class SettingsController {

    private final SettingsService service;

    public SettingsController(SettingsService service) {
        this.service = service;
    }

    @GetMapping
    public SettingsView get(Authentication authentication) {
        return service.get((Long) authentication.getPrincipal());
    }

    @PutMapping
    public SettingsView put(Authentication authentication, @RequestBody SettingsView request) {
        return service.update((Long) authentication.getPrincipal(), request);
    }
}
