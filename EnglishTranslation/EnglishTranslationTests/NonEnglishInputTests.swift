//
//  NonEnglishInputTests.swift
//  EnglishTranslationTests
//

import Foundation
import Testing
@testable import EnglishTranslation

/// TASK-114.3: text typed in another language shows its English version, and a single word or idiom opens the word card.

private struct FakeTranslator: Translating {
    var explanation: Explanation

    func explain(_ text: String, translatingTo language: TargetLanguage) async throws -> Explanation {
        explanation
    }
}

/// Knows some words. Anything else is "not an English word", like the real lookup.
private final class FakeWordLookup: WordLooking, @unchecked Sendable {
    var known: [String: WordEntry]
    var asked: [String] = []

    init(known: [String: WordEntry] = [:]) { self.known = known }

    func lookUp(_ word: String) async throws -> WordEntry {
        asked.append(word)
        guard let entry = known[word] else { throw WordLookupError.notAnEnglishWord(word) }
        return entry
    }
}

private func vietnameseAnswer(english: String? = "I am sad today.", wordMatch: String? = nil) -> Explanation {
    Explanation(
        meaning: "She feels unhappy today.", words: [], translation: "Hôm nay tôi buồn.",
        english: english, sourceLang: "vi", wordMatch: wordMatch)
}

@MainActor
struct NonEnglishInputTests {
    // MARK: - Decoding

    @Test func decodesTheNewFields() throws {
        let json = """
        {"english":"I am sad.","sourceLang":"vi","wordMatch":"sad","meaning":"m","words":[],"translation":"t"}
        """
        let explanation = try JSONDecoder().decode(Explanation.self, from: Data(json.utf8))
        #expect(explanation.english == "I am sad.")
        #expect(explanation.sourceLang == "vi")
        #expect(explanation.wordMatch == "sad")
    }

    @Test func anOldSavedAnswerStillDecodes() throws {
        let json = #"{"meaning":"m","words":[],"translation":"t"}"#
        let explanation = try JSONDecoder().decode(Explanation.self, from: Data(json.utf8))
        #expect(explanation.english == nil)
        #expect(explanation.sourceLang == nil)
        #expect(explanation.wordMatch == nil)
        #expect(explanation.englishHeadline == nil)
        #expect(explanation.wordMatchQuery == nil)
    }

    @Test func emptyEnglishAndMatchCountAsMissing() {
        let explanation = Explanation(meaning: "m", words: [], translation: "t", english: "  ", sourceLang: "vi", wordMatch: "")
        #expect(explanation.englishHeadline == nil)
        #expect(explanation.wordMatchQuery == nil)
    }

    // MARK: - The store

    @Test func theEnglishVersionTakesTheHeadlineAndTheTypedTextStaysTheSentence() async {
        let store = TranslationStore(
            makeTranslator: { FakeTranslator(explanation: vietnameseAnswer()) },
            makeWordLookup: { FakeWordLookup() }, history: nil)
        store.inputText = "Hôm nay tôi buồn"
        await store.translate()

        guard case let .loaded(result) = store.state else {
            Issue.record("Expected .loaded, got \(store.state)")
            return
        }
        #expect(result.headline == "I am sad today.")
        #expect(result.sentence == "Hôm nay tôi buồn")
    }

    @Test func englishInputKeepsTheTypedTextAsHeadline() async {
        let english = Explanation(meaning: "m", words: [], translation: "t")
        let store = TranslationStore(
            makeTranslator: { FakeTranslator(explanation: english) },
            makeWordLookup: { FakeWordLookup() }, history: nil)
        store.inputText = "I am sad today"
        await store.translate()

        guard case let .loaded(result) = store.state else {
            Issue.record("Expected .loaded, got \(store.state)")
            return
        }
        #expect(result.headline == "I am sad today")
    }

    @Test func aWordMatchOpensTheWordCard() async {
        let lookup = FakeWordLookup(known: ["sad": .run])
        let store = TranslationStore(
            makeTranslator: { FakeTranslator(explanation: vietnameseAnswer(english: "sad", wordMatch: "sad")) },
            makeWordLookup: { lookup }, history: nil)
        store.inputText = "buồn"
        await store.translate()

        guard case let .loadedWord(entry) = store.state else {
            Issue.record("Expected .loadedWord, got \(store.state)")
            return
        }
        #expect(entry == .run)
        #expect(lookup.asked == ["buồn", "sad"])
    }

    @Test func aFailedWordMatchLookupShowsTheSentenceResult() async {
        let store = TranslationStore(
            makeTranslator: { FakeTranslator(explanation: vietnameseAnswer(english: "sad", wordMatch: "gloomy")) },
            makeWordLookup: { FakeWordLookup() }, history: nil)
        store.inputText = "buồn"
        await store.translate()

        guard case let .loaded(result) = store.state else {
            Issue.record("Expected .loaded, got \(store.state)")
            return
        }
        #expect(result.headline == "sad")
        #expect(result.sentence == "buồn")
    }

    @Test func anIdiomMatchOpensItsCard() async {
        let lookup = FakeWordLookup(known: ["give up": .run])
        let store = TranslationStore(
            makeTranslator: { FakeTranslator(explanation: vietnameseAnswer(english: "give up", wordMatch: "give up")) },
            makeWordLookup: { lookup }, history: nil)
        store.inputText = "bỏ cuộc"
        await store.translate()

        guard case .loadedWord = store.state else {
            Issue.record("Expected .loadedWord, got \(store.state)")
            return
        }
        #expect(lookup.asked.last == "give up")
    }

    @Test func historyKeepsTheTypedTextForASentence() async {
        let history = MemoryHistory()
        let store = TranslationStore(
            makeTranslator: { FakeTranslator(explanation: vietnameseAnswer()) },
            makeWordLookup: { FakeWordLookup() }, history: history)
        store.inputText = "Hôm nay tôi buồn"
        await store.translate()

        let items = await history.items()
        #expect(items.first?.text == "Hôm nay tôi buồn")
        #expect(items.first?.preview == "She feels unhappy today.")
    }

    // MARK: - Quick explain

    @Test func quickExplainSendsNonEnglishTextAndKeepsTheAnswer() async {
        var explainer = QuickExplainer(
            makeWordLookup: { FakeWordLookup() },
            makeTranslator: { FakeTranslator(explanation: vietnameseAnswer()) })
        explainer.timeLimit = .milliseconds(500)
        let result = await explainer.explain("Hôm nay tôi buồn")
        #expect(result == .sentence("Hôm nay tôi buồn", vietnameseAnswer()))
        #expect(result.text == "Hôm nay tôi buồn")
    }

    @Test func quickExplainOpensTheWordCardForAMatch() async {
        var explainer = QuickExplainer(
            makeWordLookup: { FakeWordLookup(known: ["sad": .run]) },
            makeTranslator: { FakeTranslator(explanation: vietnameseAnswer(english: "sad", wordMatch: "sad")) })
        explainer.timeLimit = .milliseconds(500)
        let result = await explainer.explain("buồn")
        #expect(result == .word(.run))
    }

    @Test func quickExplainFallsBackToTheSentenceWhenTheMatchFails() async {
        var explainer = QuickExplainer(
            makeWordLookup: { FakeWordLookup() },
            makeTranslator: { FakeTranslator(explanation: vietnameseAnswer(english: "sad", wordMatch: "sad")) })
        explainer.timeLimit = .milliseconds(500)
        let result = await explainer.explain("buồn")
        #expect(result == .sentence("buồn", vietnameseAnswer(english: "sad", wordMatch: "sad")))
    }
}
