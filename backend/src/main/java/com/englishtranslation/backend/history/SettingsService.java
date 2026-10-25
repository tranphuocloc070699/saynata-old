package com.englishtranslation.backend.history;

import com.englishtranslation.backend.common.ApiException;
import java.util.Set;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Settings that follow the account: GET / PUT /api/me/settings (TASK-93.3). */
@Service
public class SettingsService {

    private static final Set<String> SHOW_TRANSLATION = Set.of("collapsed", "alwaysOpen", "remember");
    private static final Pattern LANGUAGE = Pattern.compile("[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})?");

    /** The body of GET and PUT. In a PUT, a missing field stays as it is. */
    public record SettingsView(String targetLanguage, String showTranslation, Boolean syncHistory) {
    }

    private final UserSettingsRepository settings;
    private final HistoryItemRepository history;

    public SettingsService(UserSettingsRepository settings, HistoryItemRepository history) {
        this.settings = settings;
        this.history = history;
    }

    /** The row of this user; the first call makes it with the defaults. */
    public UserSettings getOrCreate(long userId) {
        return settings.findById(userId).orElseGet(() -> settings.save(new UserSettings(userId)));
    }

    public void save(UserSettings value) {
        settings.save(value);
    }

    public SettingsView get(long userId) {
        return view(getOrCreate(userId));
    }

    /** Turning syncHistory off deletes the server history (and its tombstones). Liked stays. */
    @Transactional
    public SettingsView update(long userId, SettingsView request) {
        if (request.targetLanguage() != null && !LANGUAGE.matcher(request.targetLanguage()).matches()) {
            throw bad("invalid_target_language", "targetLanguage must be a language code like \"vi\".");
        }
        if (request.showTranslation() != null && !SHOW_TRANSLATION.contains(request.showTranslation())) {
            throw bad("invalid_show_translation", "showTranslation must be one of " + SHOW_TRANSLATION + ".");
        }
        UserSettings value = getOrCreate(userId);
        if (request.targetLanguage() != null) {
            value.setTargetLanguage(request.targetLanguage());
        }
        if (request.showTranslation() != null) {
            value.setShowTranslation(request.showTranslation());
        }
        if (request.syncHistory() != null) {
            if (value.isSyncHistory() && !request.syncHistory()) {
                history.deleteAllOf(userId);
                value.setHistoryClearedAt(null);
            }
            value.setSyncHistory(request.syncHistory());
        }
        return view(settings.save(value));
    }

    private static SettingsView view(UserSettings value) {
        return new SettingsView(value.getTargetLanguage(), value.getShowTranslation(), value.isSyncHistory());
    }

    private static ApiException bad(String code, String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, code, message);
    }
}
