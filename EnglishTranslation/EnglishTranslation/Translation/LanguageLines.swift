//
//  LanguageLines.swift
//  EnglishTranslation
//

import Foundation

/// Gets the target-language line of a word card from the backend (TASK-106.3, doc-5).
/// One call asks for every sense of the card, so opening the other senses needs no new request.
/// Lines are kept in `TranslationCache` per (text, language); the headword of a sense (TASK-106.8) per
/// (headword, text, language). A missing line or a failed call is not an error here:
/// the caller falls back to the dictionary text (Vietnamese) or Apple Translation (other languages).
@MainActor
final class LanguageLines {
    static let shared = LanguageLines(backend: { try? TranslatorFactory.makeLineTranslator() })

    private struct Key: Hashable {
        let text: String
        var headword: String?
        let language: TargetLanguage
    }

    private let backend: () -> (any LineTranslating)?
    private let cache: TranslationCache
    /// Texts that are being asked right now, so two rows that open together send one request.
    private var pending: [Key: Task<Void, Never>] = [:]
    /// The headword in the target language for one sense text.
    private var headwords: [Key: String] = [:]

    init(backend: @escaping () -> (any LineTranslating)?, cache: TranslationCache = .shared) {
        self.backend = backend
        self.cache = cache
    }

    /// The saved line for `text`, if there is one.
    func line(for text: String, in language: TargetLanguage) -> String? {
        cache.translation(of: text, in: language)
    }

    /// The saved headword of the sense `text` of the word `headword`, in `language`, if there is one.
    func headword(_ headword: String, for text: String, in language: TargetLanguage) -> String? {
        headwords[Key(text: text, headword: headword, language: language)]
    }

    /// Makes sure the lines of `texts` are in the cache when the backend has them. Returns when the answer is here.
    /// With a `headword` (the word of the card) the headword of each sense is asked too.
    /// Texts that are already cached or already being asked are not sent again.
    func load(_ texts: [String], headword: String? = nil, in language: TargetLanguage) async {
        let headword = headword.flatMap { $0.isEmpty ? nil : $0 }
        var toAsk: [String] = []
        var waits: [Task<Void, Never>] = []
        for text in Self.unique(texts) where !isLoaded(text, headword: headword, in: language) {
            if let running = pending[Key(text: text, headword: headword, language: language)] {
                waits.append(running)
            } else {
                toAsk.append(text)
            }
        }

        if !toAsk.isEmpty {
            let task = Task { await ask(toAsk, headword: headword, in: language) }
            for text in toAsk { pending[Key(text: text, headword: headword, language: language)] = task }
            waits.append(task)
        }
        for task in waits { await task.value }
    }

    private func isLoaded(_ text: String, headword: String?, in language: TargetLanguage) -> Bool {
        guard cache.translation(of: text, in: language) != nil else { return false }
        guard let headword else { return true }
        return headwords[Key(text: text, headword: headword, language: language)] != nil
    }

    private func ask(_ texts: [String], headword: String?, in language: TargetLanguage) async {
        defer { for text in texts { pending[Key(text: text, headword: headword, language: language)] = nil } }
        guard let backend = backend(),
              let lines = try? await backend.lines(for: texts, headword: headword, in: language),
              lines.count == texts.count else { return }
        for (text, line) in zip(texts, lines) {
            guard let line else { continue }
            cache.save(line.line, of: text, in: language)
            if let headword, let translated = line.headword {
                headwords[Key(text: text, headword: headword, language: language)] = translated
            }
        }
    }

    /// Non-empty texts without repeats, in order.
    private static func unique(_ texts: [String]) -> [String] {
        var seen = Set<String>()
        return texts.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}

extension WordEntry {
    /// The simple explanation of every sense: the texts one card asks the backend to translate.
    var senseDefinitions: [String] { senses.map(\.simpleDefinition) }
}
