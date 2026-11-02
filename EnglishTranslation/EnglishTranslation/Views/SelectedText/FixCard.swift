//
//  FixCard.swift
//  EnglishTranslation
//

import SwiftUI

/// The card at the top of the translation extension's sheet when the user selected text they are writing
/// (the host app allows replacing it). Mockup: `docs/design/mockups/translate-fix-option-a.html`.
/// - Checking: a spinner while the sentence is explained.
/// - A fix: the fixed text in serif with the changed words in bold (`BetterDiff`), the one-line reason, then
///   Listen and the prominent Replace button, which puts the fix back in the text box and closes the sheet.
/// - No fix: one line that says the text looks right.
/// Icon-only buttons with VoiceOver labels (CLAUDE.md "UI rule").
struct FixCard: View {
    let status: FixStatus
    /// Gets the fixed text. The sheet adds back the spaces around the selection and hands it to the host.
    let onReplace: (String) -> Void

    @Environment(SpeechPlayer.self) private var speechPlayer
    private let speechID = "fix"

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Text("Better way to say it")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textMuted)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .checking:
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Checking your text")
        case let .fixed(original, better, why):
            Text(BetterDiff(original: original, better: better).attributedString)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Theme.Colors.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .speechHighlight(isPlaying: speechPlayer.currentID == speechID)
            if let why {
                Text(why)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Theme.Spacing.small) {
                Spacer()
                listenButton(better)
                IconButton(systemImage: "checkmark", label: "Replace my text with this", isProminent: true) {
                    speechPlayer.stop()
                    onReplace(better)
                }
            }
        case .noFix:
            Text("No mistakes found.")
                .font(.body)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    private func listenButton(_ text: String) -> some View {
        let isPlaying = speechPlayer.currentID == speechID
        return IconButton(
            systemImage: isPlaying ? "stop.fill" : "speaker.wave.2",
            label: isPlaying ? "Stop" : "Listen to the better version"
        ) {
            if isPlaying {
                speechPlayer.stop()
            } else {
                speechPlayer.speak(text, id: speechID)
            }
        }
    }
}

#Preview("Fix") {
    FixCard(
        status: .fixed(
            original: "I has went to the market yesterday and buy some apple",
            better: "I went to the market yesterday and bought some apples.",
            why: "\"Yesterday\" is finished time, so both verbs use the past simple."),
        onReplace: { _ in })
        .padding()
        .background(Theme.Colors.background)
        .environment(SpeechPlayer.silent())
}

#Preview("Checking") {
    FixCard(status: .checking, onReplace: { _ in })
        .padding()
        .background(Theme.Colors.background)
        .environment(SpeechPlayer.silent())
}

#Preview("No fix") {
    FixCard(status: .noFix, onReplace: { _ in })
        .padding()
        .background(Theme.Colors.background)
        .environment(SpeechPlayer.silent())
}
