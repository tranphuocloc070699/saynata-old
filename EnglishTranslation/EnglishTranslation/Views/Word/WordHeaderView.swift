//
//  WordHeaderView.swift
//  EnglishTranslation
//

import SwiftUI

/// The top of a word card: the headword, large, with the IPA after it on the same line (it goes under the headword
/// when the line is too long, as for "beat around the bush"). A form like "ran" shows the form pill under it instead.
/// The buttons on the right come from the caller: the word card passes Listen, the share sheet passes three.
struct WordHeaderView<Actions: View>: View {
    let entry: WordEntry
    /// True while the word is read aloud (F3). The word then gets a soft highlight.
    var isSpeaking = false
    /// When set, the IPA becomes a chip with a speaker that reads the word (TASK-126, mockup A, like the
    /// Vocabulary app), so the header needs no separate Listen button. With no IPA the chip shows only the speaker.
    var onListen: (() -> Void)?
    @ViewBuilder var actions: () -> Actions

    /// The word as typed (a form like "ran" stays "ran"). With a form, the pill shows the base word.
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.small) {
            VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                if let pill = entry.formPillText {
                    headwordWithChip(ipa: nil)
                    FormPill(text: pill)
                } else if let ipa = entry.ipa {
                    // The developer's choice (TASK-83.10, mockup A): the IPA on the headword's line when it fits.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.small) {
                            headword
                            ipaText(ipa)
                        }
                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                            headword
                            ipaText(ipa)
                        }
                    }
                } else {
                    headwordWithChip(ipa: nil)
                }
            }
            Spacer()
            HStack(spacing: Theme.Spacing.small) {
                actions()
            }
        }
    }

    private var headword: some View {
        Text(entry.matchedForm?.text ?? entry.word)
            .font(.largeTitle.weight(.semibold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .speechHighlight(isPlaying: isSpeaking)
    }

    /// The headword with the speaker-only chip after it, when the card has a Listen action but no IPA to show.
    @ViewBuilder
    private func headwordWithChip(ipa: String?) -> some View {
        if onListen != nil {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.small) {
                headword
                ipaText(ipa)
            }
        } else {
            headword
        }
    }

    @ViewBuilder
    private func ipaText(_ ipa: String?) -> some View {
        if let onListen {
            Button(action: onListen) {
                HStack(spacing: Theme.Spacing.xSmall) {
                    if let ipa {
                        Text(ipa)
                            .font(.callout)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Image(systemName: isSpeaking ? "stop.fill" : "speaker.wave.2")
                        .font(.footnote)
                        .foregroundStyle(Theme.Colors.accent)
                }
                .padding(.horizontal, Theme.Spacing.small)
                .padding(.vertical, Theme.Spacing.xSmall)
                .background(Theme.Colors.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(Theme.Colors.hairline, lineWidth: 1) }
                // A taller tap area than the chip itself, toward the 44 pt minimum.
                .padding(.vertical, Theme.Spacing.small)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel(isSpeaking ? "Stop" : "Listen to the word")
            .accessibilityValue(ipa ?? "")
        } else if let ipa {
            Text(ipa)
                .font(.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize()
        }
    }
}

#Preview("Header with three buttons") {
    WordHeaderView(entry: .depend) {
        IconButton(systemImage: "speaker.wave.2", label: "Listen") {}
        IconButton(systemImage: "arrow.up.forward.app", label: "Open in Saynata") {}
        IconButton(systemImage: "xmark", label: "Close") {}
    }
    .padding()
    .background(Theme.Colors.background)
}

#Preview("Phrase, IPA under a long headword") {
    WordHeaderView(entry: WordEntry(
        word: "beat around the bush", ipa: "/ˈbit əˈɹaʊnd ðə ˈbʊʃ/",
        senses: [Sense(pos: "idiom", cefr: "B2", simpleDefinition: "to avoid saying something directly",
                       vietnamese: "nói vòng vo", examples: [])])) {
        IconButton(systemImage: "speaker.wave.2", label: "Listen") {}
    }
    .padding()
    .background(Theme.Colors.background)
}
