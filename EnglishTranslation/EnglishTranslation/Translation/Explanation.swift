//
//  Explanation.swift
//  EnglishTranslation
//

import Foundation

/// What the backend returns for one sentence.
struct Explanation: Codable, Equatable, Sendable {
    /// The sentence explained in simple English.
    let meaning: String
    /// Difficult words or phrases. Empty when there are none.
    let words: [Word]
    /// The text with its real mistakes fixed (TASK-110, prompt v10). Nil when the text is already natural,
    /// and for answers saved before v10.
    var better: String? = nil
    /// One short line in simple English that says why `better` is better. Nil when there is no fix.
    var betterWhy: String? = nil
    /// The whole sentence in the target language.
    let translation: String
    /// The natural English version of text typed in another language (TASK-114). Nil for English text, and for
    /// answers saved before prompt v12. It takes the place of the typed text at the top of the result.
    var english: String? = nil
    /// The language the text was typed in, a lowercase ISO code such as "vi". Nil for English text.
    var sourceLang: String? = nil
    /// For one non-English word, phrasal verb or idiom: the English headword to open as a word card ("buồn" gives "sad").
    /// Nil when there is none.
    var wordMatch: String? = nil

    /// The English version to show at the top, or nil when the typed text should show (English input, or an empty field).
    var englishHeadline: String? {
        guard let english = english?.trimmingCharacters(in: .whitespacesAndNewlines), !english.isEmpty else { return nil }
        return english
    }

    /// The word or phrase to open as a word card, or nil when the sentence result should show.
    var wordMatchQuery: String? {
        guard let match = wordMatch?.trimmingCharacters(in: .whitespacesAndNewlines), !match.isEmpty else { return nil }
        return match
    }

    /// One difficult word or phrase from the sentence.
    struct Word: Codable, Equatable, Sendable, Identifiable {
        /// The word as it appears in the sentence, for example "drew out".
        let word: String
        /// For example "noun", "adjective", "phrasal verb".
        let partOfSpeech: String
        /// A short explanation in simple English.
        let meaning: String

        /// The word itself is unique enough inside one sentence.
        var id: String { word }
    }
}
