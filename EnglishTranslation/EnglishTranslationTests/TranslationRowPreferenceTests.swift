//
//  TranslationRowPreferenceTests.swift
//  EnglishTranslationTests
//

import Foundation
import Testing
@testable import EnglishTranslation

struct SettingsTextTests {
    @Test func rowTitlesAndHintsAreShort() {
        #expect(TranslationRowMode.allCases.map(\.title) == ["Closed", "Always open", "Remember"])
        #expect(TranslationRowMode.allCases.allSatisfy { !$0.hint.isEmpty })
    }

    @Test func versionTextJoinsVersionAndBuild() {
        #expect(AboutView.versionText(info: ["CFBundleShortVersionString": "1.2", "CFBundleVersion": "7"]) == "1.2 (7)")
        #expect(AboutView.versionText(info: ["CFBundleShortVersionString": "1.2"]) == "1.2")
        #expect(AboutView.versionText(info: nil) == "1.0")
    }
}

struct TranslationRowPreferenceTests {

    /// A fresh, empty settings store for each test.
    private func makePreference() -> TranslationRowPreference {
        let suite = "TranslationRowPreferenceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return TranslationRowPreference(defaults: defaults)
    }

    @Test func defaultIsRememberLast() {
        let preference = makePreference()
        #expect(preference.mode == .rememberLast)
        #expect(!preference.startsOpen)
        preference.rowChanged(isOpen: true)
        #expect(preference.startsOpen)
    }

    @Test func serverValuesMatchTheAccountSettingsApi() {
        #expect(TranslationRowMode.allCases.map(\.serverValue) == ["collapsed", "alwaysOpen", "remember"])
        #expect(TranslationRowMode(serverValue: "remember") == .rememberLast)
        #expect(TranslationRowMode(serverValue: "nonsense") == nil)
    }

    @Test func collapsedStaysClosedEvenAfterAnOpen() {
        let preference = makePreference()
        preference.mode = .collapsed
        preference.rowChanged(isOpen: true)
        #expect(!preference.startsOpen)
    }

    @Test func alwaysOpenStartsOpenEvenAfterAClose() {
        let preference = makePreference()
        preference.mode = .alwaysOpen
        preference.rowChanged(isOpen: false)
        #expect(preference.startsOpen)
    }

    @Test func rememberLastStartsClosedAtFirst() {
        let preference = makePreference()
        preference.mode = .rememberLast
        #expect(!preference.startsOpen)
    }

    @Test func rememberLastFollowsTheLastChoice() {
        let preference = makePreference()
        preference.mode = .rememberLast
        preference.rowChanged(isOpen: true)
        #expect(preference.startsOpen)
        preference.rowChanged(isOpen: false)
        #expect(!preference.startsOpen)
    }

    @Test func modeIsSavedInTheStore() {
        let preference = makePreference()
        preference.mode = .alwaysOpen
        let again = TranslationRowPreference(defaults: preference.defaults)
        #expect(again.mode == .alwaysOpen)
    }

    @Test func unknownSavedValueFallsBackToTheDefault() {
        let preference = makePreference()
        preference.defaults.set("nonsense", forKey: TranslationRowPreference.modeKey)
        #expect(preference.mode == .rememberLast)
    }
}
