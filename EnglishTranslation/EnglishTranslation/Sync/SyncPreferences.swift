//
//  SyncPreferences.swift
//  EnglishTranslation
//

import Foundation

/// The sync settings kept on the device (TASK-93.4): the "Sync history" switch, and whether a settings change still
/// has to reach the server. They live in the App Group defaults, so the Share and Translate extensions see the switch.
struct SyncPreferences {
    /// Same key as `@AppStorage` in the Settings screen.
    static let historyKey = "syncHistory"
    private static let settingsDirtyKey = "accountSettingsDirty"

    var defaults: UserDefaults

    /// The App Group defaults (normal defaults if the group is not set up). In a test run each call gives a new empty suite.
    static var groupDefaults: UserDefaults {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return TargetLanguagePreference.makeEmptyDefaults()
        }
        return UserDefaults(suiteName: ResultCache.appGroupID) ?? .standard
    }

    static var shared: SyncPreferences { SyncPreferences(defaults: groupDefaults) }

    /// Should History go to the account? On unless the learner turned it off.
    var isHistoryOn: Bool {
        get { defaults.object(forKey: Self.historyKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.historyKey) }
    }

    /// True while a settings change has not reached the server yet; the next launch sends it instead of reading.
    var settingsDirty: Bool {
        get { defaults.bool(forKey: Self.settingsDirtyKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.settingsDirtyKey) }
    }
}
