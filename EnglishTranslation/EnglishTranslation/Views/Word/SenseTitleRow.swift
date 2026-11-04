//
//  SenseTitleRow.swift
//  EnglishTranslation
//

import SwiftUI

/// The title of a sense card: a number in a circle, the simple explanation with the level chip below it.
/// Used by the full card and the compact card.
struct SenseTitleRow: View {
    let number: Int
    let sense: Sense
    /// When set, a tap on the explanation reads it aloud (no speaker button, TASK-126 mockup A).
    /// The compact card leaves it nil.
    var speechID: String?

    @Environment(SpeechPlayer.self) private var speechPlayer

    private var isPlaying: Bool {
        speechID != nil && speechPlayer.currentID == speechID
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.medium) {
            Text("\(number)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 24, height: 24)
                .background(Theme.Colors.chipFill, in: Circle())
                .accessibilityLabel("Meaning \(number)")

            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                Text(sense.simpleDefinition)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .textSelection(.enabled)
                    .speechHighlight(isPlaying: isPlaying)
                    .modifier(TapToHear(isOn: speechID != nil, isPlaying: isPlaying, toggle: toggleSpeech))

                LevelChip(text: sense.chipText)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        }
    }

    private func toggleSpeech() {
        guard let speechID else { return }
        if isPlaying {
            speechPlayer.stop()
        } else {
            speechPlayer.speak(sense.simpleDefinition, id: speechID)
        }
    }
}

/// Makes a text tap-to-hear: a tap plays or stops it, and VoiceOver reads it as a button.
private struct TapToHear: ViewModifier {
    let isOn: Bool
    let isPlaying: Bool
    let toggle: () -> Void

    func body(content: Content) -> some View {
        if isOn {
            content
                .contentShape(Rectangle())
                .onTapGesture(perform: toggle)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(isPlaying ? "Stops the sound" : "Plays the sound")
        } else {
            content
        }
    }
}

#Preview {
    SenseTitleRow(number: 1, sense: WordEntry.depend.senses[0])
        .padding()
        .environment(SpeechPlayer.silent())
}
