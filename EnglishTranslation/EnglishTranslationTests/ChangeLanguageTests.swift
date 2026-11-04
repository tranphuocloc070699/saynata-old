//
//  ChangeLanguageTests.swift
//  EnglishTranslationTests
//

import Foundation
import Testing
@testable import EnglishTranslation

/// Records the language of every call, and answers with a line in that language.
private final class LanguageRecordingTranslator: Translating, @unchecked Sendable {
    var languages: [TargetLanguage] = []

    func explain(_ text: String, translatingTo language: TargetLanguage) async throws -> Explanation {
        languages.append(language)
        return Explanation(meaning: "You want to talk to everyone.", words: [], translation: "line-\(language.rawValue)")
    }
}

/// Changing the language: the result's language row in the share and translation sheet, the app's language chip
/// and the Mac picker.
@MainActor
struct ChangeLanguageTests {
    private let preference = TargetLanguagePreference(defaults: TargetLanguagePreference.makeEmptyDefaults())

    @Test func aSentenceIsAskedAgainInTheNewLanguage() async {
        let translator = LanguageRecordingTranslator()
        let store = TranslationStore(makeTranslator: { translator }, history: nil, languagePreference: preference)
        store.useTextFromElsewhere("Hi everyone, I wanna talk about something.")
        await store.translate()

        await store.changeLanguage(to: .korean)

        guard case let .loaded(result) = store.state else {
            Issue.record("Expected .loaded, got \(store.state)")
            return
        }
        #expect(result.language == .korean)
        #expect(result.explanation.translation == "line-\(TargetLanguage.korean.rawValue)")
        #expect(result.isTyped == false)
        #expect(translator.languages.last == .korean)
        #expect(preference.language == .korean)
    }

    // The app's language chip and the Mac picker use changeLanguage too (the sentence row stayed in the old
    // language when only `targetLanguage` was set, screen recording 2026-11-04).
    @Test func aTypedSentenceIsAskedAgainWhenThePickerChanges() async {
        let translator = LanguageRecordingTranslator()
        let store = TranslationStore(makeTranslator: { translator }, history: nil, languagePreference: preference)
        store.inputText = "I was considering just sharing the other thing instead."
        await store.translate()

        await store.changeLanguage(to: .japanese)

        guard case let .loaded(result) = store.state else {
            Issue.record("Expected .loaded, got \(store.state)")
            return
        }
        #expect(result.language == .japanese)
        #expect(result.explanation.translation == "line-\(TargetLanguage.japanese.rawValue)")
        #expect(translator.languages.last == .japanese)
    }

    @Test func editedTextWaitsForExplainWhenThePickerChanges() async {
        let translator = LanguageRecordingTranslator()
        let store = TranslationStore(makeTranslator: { translator }, history: nil, languagePreference: preference)
        store.inputText = "I was considering just sharing the other thing instead."
        await store.translate()
        let calls = translator.languages.count
        store.inputText = "A new sentence that was not explained yet."

        await store.changeLanguage(to: .french)

        #expect(translator.languages.count == calls)
        #expect(store.targetLanguage == .french)
    }

    @Test func theSameLanguageAsksNothing() async {
        let translator = LanguageRecordingTranslator()
        let store = TranslationStore(makeTranslator: { translator }, history: nil, languagePreference: preference)
        store.useTextFromElsewhere("Hi everyone, I wanna talk about something.")
        await store.translate()
        let calls = translator.languages.count

        await store.changeLanguage(to: store.targetLanguage)

        #expect(translator.languages.count == calls)
    }
}
