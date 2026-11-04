//
//  FixStatusTests.swift
//  EnglishTranslationTests
//

import Foundation
import Testing
@testable import EnglishTranslation

/// The Fix card in the translation extension (option A, 2026-11-02): what it shows for each state,
/// and the text that goes back in the host app's text box.
@MainActor
struct FixStatusTests {
    private func loaded(_ sentence: String, better: String?, why: String? = nil) -> TranslationState {
        .loaded(SentenceResult(
            sentence: sentence,
            explanation: Explanation(meaning: "You went shopping.", words: [], better: better, betterWhy: why, translation: ""),
            language: .vietnamese,
            isTyped: false))
    }

    @Test func showsTheFixWithItsReason() {
        let state = loaded("I has went to the market", better: "I went to the market.", why: "Use the past simple.")
        #expect(FixStatus(state: state)
            == .fixed(original: "I has went to the market", better: "I went to the market.", why: "Use the past simple."))
    }

    @Test func saysNoMistakesWhenThereIsNoFix() {
        #expect(FixStatus(state: loaded("I went to the market.", better: nil)) == .noFix)
    }

    @Test func checksWhileTheSentenceIsLoading() {
        #expect(FixStatus(state: .loading) == .checking)
    }

    @Test func showsNoCardForIdleOrErrors() {
        #expect(FixStatus(state: .idle) == nil)
        #expect(FixStatus(state: .failed("No connection")) == nil)
    }

    @Test func replacementKeepsTheSpacesAroundTheSelection() {
        #expect(FixStatus.replacement(selected: "i has went ", better: "I went.") == "I went. ")
        #expect(FixStatus.replacement(selected: "\n  i has went\n", better: " I went. ") == "\n  I went.\n")
        #expect(FixStatus.replacement(selected: "i has went", better: "I went.") == "I went.")
    }

    @Test func replacementNeverEmptiesTheTextBox() {
        #expect(FixStatus.replacement(selected: "i has went", better: "   ") == "i has went")
        #expect(FixStatus.replacement(selected: "   ", better: "I went.") == "   ")
    }
}
