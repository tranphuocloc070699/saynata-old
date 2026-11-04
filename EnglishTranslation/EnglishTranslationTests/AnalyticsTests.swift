//
//  AnalyticsTests.swift
//  EnglishTranslationTests
//
//  Usage events (TASK-128.3): names and properties match docs/analytics/events.md, key flows send the right
//  event with the right source, the switch stops everything, and no event carries the looked-up text.
//

import Foundation
import Testing
@testable import EnglishTranslation

/// Records what would go to PostHog.
@MainActor
final class FakeAnalyticsSender: AnalyticsSending {
    private(set) var events: [AnalyticsEvent] = []
    private(set) var identified: [Int] = []
    private(set) var resetCount = 0
    private(set) var sharing: [Bool] = []

    func send(_ event: AnalyticsEvent) { events.append(event) }
    func identify(userID: Int) { identified.append(userID) }
    func reset() { resetCount += 1 }
    func setSignedIn(_ isSignedIn: Bool) {}
    func setSharing(_ isOn: Bool) { sharing.append(isOn) }
}

private struct AnalyticsTranslator: Translating {
    func explain(_ text: String, translatingTo language: TargetLanguage) async throws -> Explanation {
        Explanation(meaning: "She did not want to go.", words: [], translation: "Cô ấy không muốn đi.")
    }
}

private struct AnalyticsWordLookup: WordLooking {
    var error: Error?
    func lookUp(_ word: String) async throws -> WordEntry {
        if let error { throw error }
        return .run
    }
}

@MainActor
private final class QuietSynthesizer: SpeechSynthesizing {
    var onUtteranceEnded: ((_ token: Int) -> Void)?
    func speak(_ text: String, token: Int) {}
    func stop() {}
}

private final class MemoryLikedCopy: LikedCopyStoring, @unchecked Sendable {
    private var stored: [SavedItem] = []
    func load() -> [SavedItem] { stored }
    func save(_ items: [SavedItem]) { stored = items }
}

@MainActor
struct AnalyticsTests {
    /// An `Analytics` with a fake sender and its own empty defaults, so the switch starts on.
    private func makeAnalytics() -> (Analytics, FakeAnalyticsSender, UsageSharingPreference) {
        let sender = FakeAnalyticsSender()
        let preference = UsageSharingPreference(defaults: TargetLanguagePreference.makeEmptyDefaults())
        return (Analytics(sender: sender, preference: preference), sender, preference)
    }

    private func makeStore(
        analytics: Analytics, source: LookupSource = .app, wordError: Error? = nil
    ) -> TranslationStore {
        TranslationStore(
            makeTranslator: { AnalyticsTranslator() },
            makeWordLookup: { AnalyticsWordLookup(error: wordError) },
            history: nil,
            languagePreference: TargetLanguagePreference(defaults: TargetLanguagePreference.makeEmptyDefaults()),
            source: source,
            analytics: analytics,
            rowPreference: TranslationRowPreference(defaults: TargetLanguagePreference.makeEmptyDefaults()))
    }

    // MARK: - The event list

    @Test func namesMatchTheSharedList() {
        #expect(AnalyticsEvent.listenTapped(part: .word).name == "listen_tapped")
        #expect(AnalyticsEvent.languageRowOpened(language: .vietnamese, kind: .word).name == "language_row_opened")
        #expect(AnalyticsEvent.itemLiked(kind: .word).name == "item_liked")
        #expect(AnalyticsEvent.quickExplainUsed.name == "quick_explain_used")
        #expect(AnalyticsEvent.signedIn(method: .google).name == "signed_in")
        let done = AnalyticsEvent.lookupDone(
            kind: .sentence, source: .translateSheet, length: .s, language: .korean, rowStartsOpen: false)
        #expect(done.name == "lookup_done")
        #expect(done.properties == [
            "kind": "sentence", "source": "translate_sheet", "length": "s", "lang": "ko", "row_start": "closed",
        ])
    }

    @Test func lengthBuckets() {
        #expect(LengthBucket(text: "run") == .xs)
        #expect(LengthBucket(text: String(repeating: "a", count: 20)) == .xs)
        #expect(LengthBucket(text: String(repeating: "a", count: 21)) == .s)
        #expect(LengthBucket(text: String(repeating: "a", count: 81)) == .m)
        #expect(LengthBucket(text: String(repeating: "a", count: 201)) == .l)
    }

    @Test func listenPartFromSpeechID() {
        #expect(ListenPart(speechID: "word") == .word)
        #expect(ListenPart(speechID: "word-run") == .word)
        #expect(ListenPart(speechID: "example-0-1") == .example)
        #expect(ListenPart(speechID: "sense-2") == .meaning)
        #expect(ListenPart(speechID: "summary") == .meaning)
        #expect(ListenPart(speechID: "sentence") == .sentence)
        #expect(ListenPart(speechID: "selected-text") == .selected)
    }

    // MARK: - Lookups

    @Test func typedWordSendsLookupDoneFromTheApp() async {
        let (analytics, sender, _) = makeAnalytics()
        let store = makeStore(analytics: analytics)
        store.inputText = "run"
        await store.translate()
        #expect(sender.events == [
            .lookupDone(kind: .word, source: .app, length: .xs, language: .vietnamese, rowStartsOpen: false),
        ])
    }

    @Test func sharedSentenceKeepsItsSource() async {
        let (analytics, sender, _) = makeAnalytics()
        let store = makeStore(analytics: analytics)
        store.useTextFromElsewhere("She didn't want to go to the party.", source: .services)
        await store.translate()
        #expect(sender.events.count == 1)
        guard case let .lookupDone(kind, source, _, _, _) = sender.events.first else {
            Issue.record("Expected lookup_done")
            return
        }
        #expect(kind == .sentence)
        #expect(source == .services)
    }

    @Test func typingAfterSharedTextIsTheUsersOwn() async {
        let (analytics, sender, _) = makeAnalytics()
        let store = makeStore(analytics: analytics, source: .panel)
        store.useTextFromElsewhere("run", source: .copied)
        store.inputText = "walk"
        await store.translate()
        guard case let .lookupDone(_, source, _, _, _) = sender.events.first else {
            Issue.record("Expected lookup_done")
            return
        }
        #expect(source == .panel)
    }

    @Test func guestLimitSendsLookupFailed() async {
        let (analytics, sender, _) = makeAnalytics()
        let store = makeStore(analytics: analytics, wordError: BackendError.signInRequired)
        store.inputText = "run"
        await store.translate()
        #expect(sender.events == [.lookupFailed(kind: .word, source: .app, reason: .signInRequired)])
    }

    @Test func pickingALanguageSendsLanguageChanged() {
        let (analytics, sender, _) = makeAnalytics()
        let store = makeStore(analytics: analytics)
        store.pickedLanguage = .korean
        store.pickedLanguage = .korean // the same again: nothing
        #expect(sender.events == [.languageChanged(language: .korean)])
    }

    // MARK: - Other flows

    @Test func listenSendsListenTapped() {
        let (analytics, sender, _) = makeAnalytics()
        let player = SpeechPlayer(synthesizer: QuietSynthesizer(), analytics: analytics)
        player.speak("an example", id: "example-0-0")
        player.speak("   ", id: "word") // empty text plays nothing
        #expect(sender.events == [.listenTapped(part: .example)])
    }

    @Test func likeAndUnlikeSendTheirEvents() async {
        let (analytics, sender, _) = makeAnalytics()
        let liked = LikedStore(copy: MemoryLikedCopy(), outbox: nil, isSignedIn: { true }, analytics: analytics)
        let item = SavedItem(kind: .word, text: "apple", preview: "a fruit")
        await liked.toggle(item)
        await liked.toggle(item)
        #expect(sender.events == [.itemLiked(kind: .word), .itemUnliked(kind: .word)])
    }

    @Test func openingTheLanguageRowSendsAnEvent() {
        let (analytics, sender, _) = makeAnalytics()
        let rows = TranslationRowPreference(defaults: TargetLanguagePreference.makeEmptyDefaults())
        rows.rowTapped(isOpen: true, language: .vietnamese, kind: .sentence, analytics: analytics)
        rows.rowTapped(isOpen: false, language: .vietnamese, kind: .sentence, analytics: analytics)
        #expect(sender.events == [.languageRowOpened(language: .vietnamese, kind: .sentence)])
    }

    // MARK: - Switch and privacy

    @Test func switchOffSendsNothing() async {
        let (analytics, sender, preference) = makeAnalytics()
        preference.isOn = false
        analytics.sharingChanged()
        let store = makeStore(analytics: analytics)
        store.inputText = "run"
        await store.translate()
        #expect(sender.events.isEmpty)
        #expect(sender.sharing == [false])
    }

    @Test func noEventCarriesTheText() async {
        let (analytics, sender, _) = makeAnalytics()
        let store = makeStore(analytics: analytics)
        let sentence = "Uniquephrase didn't want to go."
        store.inputText = sentence
        await store.translate()
        #expect(!sender.events.isEmpty)
        for event in sender.events {
            for value in event.properties.values {
                #expect(!value.localizedCaseInsensitiveContains("uniquephrase"))
            }
        }
    }

    @Test func signInIdentifiesByUserIDAndSignOutResets() {
        let (analytics, sender, _) = makeAnalytics()
        analytics.signedIn(userID: 42, method: .emailCode)
        analytics.signedOut()
        #expect(sender.identified == [42])
        #expect(sender.events == [.signedIn(method: .emailCode)])
        #expect(sender.resetCount == 1)
    }
}
