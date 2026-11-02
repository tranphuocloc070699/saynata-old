//
//  InPlaceText.swift
//  EnglishTranslation
//
//  Text in place (TASK-121.7, mockup 6A): a line in another language gets English drawn over it, and a tapped line
//  shows its simple English explanation right below it. The English line is made on the phone (Apple Translation);
//  the explanation is the normal sentence answer (explain first, the language line last).
//

import Foundation
import NaturalLanguage

/// Tells which language a line is in. Behind a protocol so tests use a fake.
protocol LanguageDetecting: Sendable {
    /// A language code from `InPlaceText.sourceLanguages` or "en", or nil when it is not sure.
    func language(of text: String) -> String?
}

/// Makes the English version of short lines, all in one language. The real one wraps an Apple `TranslationSession`.
protocol EnglishMaking {
    func english(for texts: [String]) async throws -> [String]
}

enum InPlaceText {
    /// Languages drawn over in English: the app's target languages (Apple Translation codes).
    static let sourceLanguages = ["vi", "zh-Hans", "zh-Hant", "ja", "ko", "fr", "es", "de"]
}

/// NaturalLanguage, limited to English and `InPlaceText.sourceLanguages`. Short or unclear lines give nil.
struct NLLanguageDetector: LanguageDetecting {
    static let minimumConfidence = 0.6

    func language(of text: String) -> String? {
        guard text.count >= 3 else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = (["en"] + InPlaceText.sourceLanguages).map { NLLanguage(rawValue: $0) }
        recognizer.processString(text)
        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
              confidence >= Self.minimumConfidence else { return nil }
        return language.rawValue
    }
}

/// One language whose lines wait for their English. `id` changes for every new request, so the view starts a new
/// translation task even when the language is the same.
struct EnglishRequest: Equatable {
    let language: String
    let id: Int
}

/// The explanation of the tapped line.
enum LineExplanation: Equatable {
    case idle
    case loading
    case loaded(Explanation)
    case failed(String)
}
