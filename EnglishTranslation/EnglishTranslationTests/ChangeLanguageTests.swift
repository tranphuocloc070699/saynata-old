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

/// The language menu on the result's language row in the share and translation sheet.
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
