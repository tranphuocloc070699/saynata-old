//
//  FixStatus.swift
//  EnglishTranslation
//

import Foundation

/// What the Fix card shows (the fix sheet, option A, 2026-11-02): the system "Translate" item on text the user is writing
/// opens Saynata's sheet, and the card on top offers the fixed text to put back in the text box.
/// The fix is the sentence answer's own `better` field (TASK-110), so there is no extra backend call.
enum FixStatus: Equatable {
    /// The sentence is still being explained.
    case checking
    /// The text has a real mistake: the fixed text, the text it was made from, and one line that says why.
    case fixed(original: String, better: String, why: String?)
    /// The explanation is there and the backend found nothing to fix.
    case noFix

    /// Nil when there is no card to show: nothing asked yet, a word card, or an error (the sheet shows those itself).
    init?(state: TranslationState) {
        switch state {
        case .loading, .meaning:
            self = .checking
        case let .loaded(result):
            if let better = result.explanation.better {
                self = .fixed(original: result.sentence, better: better, why: result.explanation.betterWhy)
            } else {
                self = .noFix
            }
        case .idle, .loadedWord, .failed:
            return nil
        }
    }

    /// The text that goes back in the host app's text box. The fix is made from the trimmed text, so the spaces
    /// and line breaks the user selected around it are kept: only the words change.
    static func replacement(selected: String, better: String) -> String {
        let core = better.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !core.isEmpty, selected.contains(where: { !$0.isWhitespace }) else { return selected }
        let leading = selected.prefix(while: \.isWhitespace)
        let trailing = selected.reversed().prefix(while: \.isWhitespace)
        return String(leading) + core + String(trailing.reversed())
    }
}
