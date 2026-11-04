//
//  AnalyticsEvent.swift
//  EnglishTranslation
//
//  The usage events of `docs/analytics/events.md` (TASK-128.1, TASK-128.3). The names and property values here
//  must match that file exactly: the web site and the browser extension send the same ones.
//
//  Privacy rule: no event carries what the learner looked up, typed, selected or copied. Only fixed choices
//  (kind, source, a length bucket, a language code) leave the device.
//

import Foundation

/// What was looked up.
enum LookupKind: String, Sendable, Equatable {
    case word
    /// 2 to 6 words shown as a word card (TASK-83.10).
    case phrase
    case sentence
}

/// Where a lookup started (`source` in events.md).
enum LookupSource: String, Sendable, Equatable {
    /// Typed or pasted in the iPhone app.
    case app
    /// "Explain copied text" (Back Tap, Action Button), or the Mac shortcut with freshly copied text.
    case copied
    /// The Share extension, or "Open in Saynata" from it.
    case share
    /// The system Translate sheet (TranslationExtension).
    case translateSheet = "translate_sheet"
    /// Quick explain (App Intent, Shortcuts or Siri).
    case intent
    /// Typed in the Mac popover or floating panel.
    case panel
    /// The Mac Services item "Explain with Saynata".
    case services
}

/// How long the looked-up text was, in groups, so the text itself never leaves the device.
enum LengthBucket: String, Sendable, Equatable {
    case xs, s, m, l

    /// Counts UTF-16 units of the trimmed text, like the 500-character limit.
    init(text: String) {
        let count = text.trimmingCharacters(in: .whitespacesAndNewlines).utf16.count
        switch count {
        case ...20: self = .xs
        case 21...80: self = .s
        case 81...200: self = .m
        default: self = .l
        }
    }
}

/// Why a lookup showed an error.
enum LookupFailReason: String, Sendable, Equatable {
    case signInRequired = "sign_in_required"
    case dailyLimit = "daily_limit"
    case notEnglish = "not_english"
    case offline
    case server

    init(error: Error) {
        switch error {
        case BackendError.signInRequired: self = .signInRequired
        case BackendError.dailyLimitReached: self = .dailyLimit
        case is WordLookupError: self = .notEnglish
        case is URLError: self = .offline
        default: self = .server
        }
    }
}

/// Which Listen icon was tapped.
enum ListenPart: String, Sendable, Equatable {
    case word
    case example
    case meaning
    case sentence
    /// The header of the Share and Translate sheet (a word or a sentence).
    case selected

    /// The part from the speech id the views give `SpeechPlayer` ("word", "sense-0", "example-0-1", "sentence",
    /// "summary", "part", "fix", "selected-text"). An unknown id counts as `meaning`.
    init(speechID: String) {
        if speechID == "word" || speechID.hasPrefix("word-") {
            self = .word
        } else if speechID.hasPrefix("example-") {
            self = .example
        } else if speechID == "sentence" || speechID == "fix" {
            self = .sentence
        } else if speechID == "selected-text" {
            self = .selected
        } else {
            self = .meaning
        }
    }
}

/// How the learner signed in.
enum SignInMethod: String, Sendable, Equatable {
    case emailCode = "email_code"
    case emailLink = "email_link"
    case google
    case apple
}

/// One usage event. `name` and `properties` are what PostHog receives.
enum AnalyticsEvent: Sendable, Equatable {
    case lookupDone(kind: LookupKind, source: LookupSource, length: LengthBucket, language: TargetLanguage, rowStartsOpen: Bool)
    case lookupFailed(kind: LookupKind, source: LookupSource, reason: LookupFailReason)
    case listenTapped(part: ListenPart)
    case languageRowOpened(language: TargetLanguage, kind: LookupKind)
    case itemLiked(kind: SavedItem.Kind)
    case itemUnliked(kind: SavedItem.Kind)
    case sentenceWordOpened(hasEntry: Bool)
    case suggestionTapped
    case historyOpened
    case quickExplainUsed
    case languageChanged(language: TargetLanguage)
    case signedIn(method: SignInMethod)

    var name: String {
        switch self {
        case .lookupDone: "lookup_done"
        case .lookupFailed: "lookup_failed"
        case .listenTapped: "listen_tapped"
        case .languageRowOpened: "language_row_opened"
        case .itemLiked: "item_liked"
        case .itemUnliked: "item_unliked"
        case .sentenceWordOpened: "sentence_word_opened"
        case .suggestionTapped: "suggestion_tapped"
        case .historyOpened: "history_opened"
        case .quickExplainUsed: "quick_explain_used"
        case .languageChanged: "language_changed"
        case .signedIn: "signed_in"
        }
    }

    /// Only values from events.md: no text the learner looked up.
    var properties: [String: String] {
        switch self {
        case let .lookupDone(kind, source, length, language, rowStartsOpen):
            ["kind": kind.rawValue, "source": source.rawValue, "length": length.rawValue,
             "lang": language.code, "row_start": rowStartsOpen ? "open" : "closed"]
        case let .lookupFailed(kind, source, reason):
            ["kind": kind.rawValue, "source": source.rawValue, "reason": reason.rawValue]
        case let .listenTapped(part):
            ["part": part.rawValue]
        case let .languageRowOpened(language, kind):
            ["lang": language.code, "kind": kind.rawValue]
        case let .itemLiked(kind), let .itemUnliked(kind):
            ["kind": kind.rawValue]
        case let .sentenceWordOpened(hasEntry):
            ["has_entry": hasEntry ? "true" : "false"]
        case .suggestionTapped, .quickExplainUsed:
            [:]
        case .historyOpened:
            ["tab": "history"]
        case let .languageChanged(language):
            ["lang": language.code]
        case let .signedIn(method):
            ["method": method.rawValue]
        }
    }
}

extension QuickExplainResult {
    /// The `lookup_done` or `lookup_failed` event for a Quick explain card (source `intent`). Nil for text that was
    /// never sent (empty, too long).
    func usageEvent(text: String, language: TargetLanguage,
                    rowPreference: TranslationRowPreference = TranslationRowPreference()) -> AnalyticsEvent? {
        let kind: LookupKind = CacheKeys.wordQuery(text) != nil ? .word : .sentence
        switch self {
        case .word:
            return .lookupDone(kind: .word, source: .intent, length: LengthBucket(text: text),
                               language: language, rowStartsOpen: rowPreference.startsOpen)
        case .sentence:
            return .lookupDone(kind: .sentence, source: .intent, length: LengthBucket(text: text),
                               language: language, rowStartsOpen: rowPreference.startsOpen)
        case .signInNeeded:
            return .lookupFailed(kind: kind, source: .intent, reason: .signInRequired)
        case .slow, .failed:
            return .lookupFailed(kind: kind, source: .intent, reason: .server)
        case .problem:
            return nil
        }
    }
}
