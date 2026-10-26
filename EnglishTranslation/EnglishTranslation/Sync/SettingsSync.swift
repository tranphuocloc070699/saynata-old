//
//  SettingsSync.swift
//  EnglishTranslation
//

import Foundation

/// Keeps the settings that follow the account (language, Show translation, Sync history) the same on every device
/// through `GET`/`PUT /api/me/settings` (TASK-93.4). A change is saved on the device first and sent in the background.
/// If sending fails the change stays marked, and the next launch sends it instead of overwriting it.
@MainActor
final class SettingsSync {
    static let shared = SettingsSync(
        makeAPI: { BackendClient(baseURL: try AppConfig.backendBaseURL(), cache: nil, auth: AccountStore.shared) },
        isSignedIn: { AccountStore.shared.isSignedIn },
        language: .shared,
        rows: TranslationRowPreference(),
        sync: .shared)

    private let makeAPI: @MainActor () throws -> any SyncAPI
    private let isSignedIn: @MainActor () -> Bool
    private let language: TargetLanguagePreference
    private let rows: TranslationRowPreference
    private let sync: SyncPreferences
    private let delay: Duration
    private let sleep: @Sendable (Duration) async throws -> Void
    private var pushTask: Task<Void, Never>?
    /// What the server has, as far as we know. A push of the same values is skipped.
    private var lastKnown: AccountSettings?

    init(
        makeAPI: @escaping @MainActor () throws -> any SyncAPI,
        isSignedIn: @escaping @MainActor () -> Bool,
        language: TargetLanguagePreference,
        rows: TranslationRowPreference,
        sync: SyncPreferences,
        delay: Duration = .seconds(1),
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.makeAPI = makeAPI
        self.isSignedIn = isSignedIn
        self.language = language
        self.rows = rows
        self.sync = sync
        self.delay = delay
        self.sleep = sleep
    }

    /// The settings of this device, in the shape of the API.
    var current: AccountSettings {
        AccountSettings(
            targetLanguage: language.language.code,
            showTranslation: rows.mode.serverValue,
            syncHistory: sync.isHistoryOn)
    }

    /// A setting changed on this device: send all three in the background, after a short quiet time.
    func settingsChanged() {
        guard isSignedIn(), current != lastKnown else { return }
        sync.settingsDirty = true
        pushTask?.cancel()
        pushTask = Task { [delay, sleep] in
            do { try await sleep(delay) } catch { return }
            guard !Task.isCancelled else { return }
            await push()
        }
    }

    /// Launch, sign-in, return to the foreground. Sends a change that is still waiting; otherwise reads the account's
    /// settings into this device. Returns the language when it changed, so the screen can follow.
    @discardableResult
    func syncNow() async -> TargetLanguage? {
        guard isSignedIn() else { return nil }
        if sync.settingsDirty {
            await push()
            return nil
        }
        guard let remote = try? await makeAPI().accountSettings() else { return nil }
        lastKnown = remote
        let before = language.language
        language.language = TargetLanguage(savedCode: remote.targetLanguage)
        rows.mode = TranslationRowMode(serverValue: remote.showTranslation) ?? rows.mode
        sync.isHistoryOn = remote.syncHistory
        return language.language == before ? nil : language.language
    }

    private func push() async {
        guard isSignedIn() else { return }
        let settings = current
        do {
            try await makeAPI().updateAccountSettings(settings)
            lastKnown = settings
            // A change made while the call ran keeps the mark.
            if current == settings { sync.settingsDirty = false }
        } catch {
            // Stays marked: the next launch or return to the app tries again.
        }
    }
}
