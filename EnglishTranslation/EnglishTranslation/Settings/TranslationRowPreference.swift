//
//  TranslationRowPreference.swift
//  EnglishTranslation
//

import Foundation

/// How the target-language row (for example "Vietnamese") opens on word cards and sentence results.
enum TranslationRowMode: String, CaseIterable, Identifiable {
    /// Closed every time.
    case collapsed
    /// Open every time.
    case alwaysOpen
    /// Starts the way the learner last left a row. This is the default (CLAUDE.md "Product rule", TASK-93.4).
    case rememberLast

    var id: Self { self }

    /// The value the account settings API uses (`GET`/`PUT /api/me/settings`).
    var serverValue: String {
        switch self {
        case .collapsed: "collapsed"
        case .alwaysOpen: "alwaysOpen"
        case .rememberLast: "remember"
        }
    }

    init?(serverValue: String) {
        guard let mode = Self.allCases.first(where: { $0.serverValue == serverValue }) else { return nil }
        self = mode
    }

    /// The text in the Settings list.
    var title: String {
        switch self {
        case .collapsed: "Closed"
        case .alwaysOpen: "Always open"
        case .rememberLast: "Remember"
        }
    }

    /// The short line under the title in the Settings list.
    var hint: String {
        switch self {
        case .collapsed: "Tap to open each time"
        case .alwaysOpen: "Shown under every result"
        case .rememberLast: "Stays how you left it"
        }
    }
}

/// Reads and saves the "Show translation" setting. Views ask `startsOpen` when a row appears,
/// and call `rowChanged(isOpen:)` when the learner opens or closes a row.
/// The values live in `UserDefaults`, so they stay after the app closes.
struct TranslationRowPreference {
    /// Same key as `@AppStorage` in the Settings screen.
    static let modeKey = "showTranslationMode"
    private static let lastOpenKey = "showTranslationLastOpen"

    var defaults: UserDefaults = .standard

    /// The saved mode. "Remember last choice" if nothing is saved yet.
    var mode: TranslationRowMode {
        get { TranslationRowMode(rawValue: defaults.string(forKey: Self.modeKey) ?? "") ?? .rememberLast }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.modeKey) }
    }

    /// The last open or closed state the learner set on any target-language row.
    private var lastOpen: Bool {
        get { defaults.bool(forKey: Self.lastOpenKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.lastOpenKey) }
    }

    /// Should a new result show its target-language row open?
    var startsOpen: Bool {
        switch mode {
        case .collapsed: false
        case .alwaysOpen: true
        case .rememberLast: lastOpen
        }
    }

    /// Call when the learner taps a target-language row. Only "Remember last choice" uses it.
    func rowChanged(isOpen: Bool) {
        lastOpen = isOpen
    }

    /// The learner tapped a target-language row: saves it like `rowChanged`, and an opened row sends
    /// `language_row_opened` (TASK-128.3), the number behind "explain first, translate last".
    @MainActor
    func rowTapped(isOpen: Bool, language: TargetLanguage, kind: LookupKind, analytics: Analytics = .shared) {
        rowChanged(isOpen: isOpen)
        if isOpen { analytics.track(.languageRowOpened(language: language, kind: kind)) }
    }
}
