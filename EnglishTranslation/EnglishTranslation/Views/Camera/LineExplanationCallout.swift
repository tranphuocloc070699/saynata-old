//
//  LineExplanationCallout.swift
//  EnglishTranslation
//
//  The bubble under a tapped line (TASK-121.7, mockup 6A): the simple English explanation with Listen, "In simple
//  words", the language row last (closed), and a button that opens the full result.
//

import SwiftUI

struct LineExplanationCallout: View {
    let explanation: LineExplanation
    let language: TargetLanguage
    /// Opens the full sentence result on the home screen.
    let onOpenFull: () -> Void

    @Environment(SpeechPlayer.self) private var speechPlayer
    @State private var isLanguageOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            switch explanation {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                    .accessibilityLabel("Explaining")
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(Theme.Colors.error)
            case let .loaded(answer):
                loaded(answer)
            }
        }
        .padding(Theme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("What this line means")
    }

    @ViewBuilder
    private func loaded(_ answer: Explanation) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.small) {
            Text(answer.meaning)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            IconButton(systemImage: "speaker.wave.2", label: "Listen") {
                speechPlayer.speak(answer.meaning, id: "camera-line")
            }
        }
        Text("In simple words")
            .font(.caption)
            .foregroundStyle(Theme.Colors.textMuted)
        if !answer.translation.isEmpty {
            HairlineDivider()
            FoldedRow(title: language.title, isExpanded: $isLanguageOpen) {
                Text(answer.translation)
                    .font(.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        HStack {
            Spacer()
            IconButton(systemImage: "arrow.up.forward.square", label: "Open the full result", action: onOpenFull)
        }
    }
}

/// Puts the bubble right under the line, or above it when the line is low on the screen.
struct CalloutPlacement {
    static let arrowHeight: CGFloat = 10

    /// The top of the bubble (or its bottom when `above`), in the overlay's coordinates.
    static func place(lineRect: CGRect, in size: CGSize) -> (y: CGFloat, above: Bool) {
        let above = lineRect.midY > size.height * 0.55
        return above ? (lineRect.minY - arrowHeight, true) : (lineRect.maxY + arrowHeight, false)
    }
}
