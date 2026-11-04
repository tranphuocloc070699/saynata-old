//
//  SentenceCard.swift
//  EnglishTranslation
//

import SwiftUI

/// The sentence result (TASK-124, mockup B of 2026-11-02, simple first): one card with
/// - one grey line "Original: …" (cut to one line); a tap opens the full sentence with its Listen button;
/// - the simple summary as the headline (serif, body size, **bold** key words) and the caption "In simple words",
///   then one quiet row of plain icons: Listen, Like, Copy (copies the original sentence);
/// - when the text has a real mistake, "Better way to say it", shown open: the fixed text with the changed words in
///   bold (tap it to hear it), one Copy icon, and one line that says why (TASK-110);
/// - the target language, folded and closed (CLAUDE.md "Product rule"), last.
///
/// Used by the finished result and by the loading screens, so nothing jumps when the full result arrives:
/// the original shows at once, the summary grows word by word, and the target-language row appears at the end.
struct SentenceCard: View {
    let sentence: String
    /// The text saved in History and Liked, when it is not `sentence`: the text the user typed, while `sentence`
    /// shows its English version (TASK-114). Nil: they are the same.
    var savedText: String?
    /// The simple summary so far. Empty while nothing is written: the card shows a spinner there.
    let summary: String
    /// Nil while the answer is still streaming: the folded row is left out until it is there.
    let translation: String?
    /// The language the translation was made in. It titles the folded row.
    let language: TargetLanguage
    /// The text with its mistakes fixed. Nil hides the row: no fix, or text from another app.
    var better: String?
    /// One line that says why the fix is better.
    var betterWhy: String?
    /// Gets the full word card for a tapped word. The real one is `TranslationStore.wordEntry(for:)`.
    var loadWordEntry: (SentenceWordInfo) async throws -> WordEntry = { word in
        guard let entry = word.entry else { throw WordLookupError.notOneWord }
        return entry
    }

    @Environment(SpeechPlayer.self) private var speechPlayer
    /// Starts the way "Show translation" in Settings says.
    @State private var isTranslationOpen = TranslationRowPreference().startsOpen
    /// True for a moment after Copy, so the icon shows a check mark.
    @State private var didCopy = false
    /// The original sentence starts as one grey line (TASK-124).
    @State private var isOriginalOpen = false
    @State private var didCopyBetter = false

    private let sentenceSpeechID = "sentence"
    private let summarySpeechID = "summary"
    private let betterSpeechID = "better"

    /// True when the backend sent a real language line. It sends "" (never null) when it has none.
    static func hasLanguageLine(_ translation: String) -> Bool {
        !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        card
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            originalBlock

            summaryBlock

            // Only with the finished answer, so the block does not appear in the middle of the stream.
            if translation != nil, let better {
                HairlineDivider()
                betterBlock(better)
            }

            // No translation yet (the answer is still streaming): the row appears when the full result arrives.
            // "" means the backend had no line for this language (a guest, offline cache): no row (TASK-106.6).
            if let translation, Self.hasLanguageLine(translation) {
                FoldedRow(title: language.title, isExpanded: $isTranslationOpen) {
                    Text(translation)
                        .font(.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: isTranslationOpen) { _, isOpen in
                    TranslationRowPreference().rowChanged(isOpen: isOpen)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    /// "Original: …" in one grey line; a tap shows the whole sentence (words still tappable) and its Listen button.
    @ViewBuilder
    private var originalBlock: some View {
        Button {
            withAnimation(.snappy) { isOriginalOpen.toggle() }
        } label: {
            HStack(spacing: Theme.Spacing.xSmall) {
                Text("Original:")
                    .fontWeight(.semibold)
                if !isOriginalOpen {
                    Text(sentence)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .rotationEffect(.degrees(isOriginalOpen ? 180 : 0))
            }
            .font(.footnote)
            .foregroundStyle(Theme.Colors.textMuted)
            .frame(minHeight: Theme.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOriginalOpen ? "Hide the original sentence" : "Original: \(sentence)")
        .accessibilityHint(isOriginalOpen ? "" : "Shows the whole sentence")

        if isOriginalOpen {
            HStack(alignment: .top, spacing: Theme.Spacing.small) {
                SentenceTextView(text: sentence, style: .summary, language: language, loadWordEntry: loadWordEntry, readsMarkup: false)
                    .speechHighlight(isPlaying: speechPlayer.currentID == sentenceSpeechID)
                    .padding(.top, Theme.Spacing.small)
                // The words are tappable (word sheet), so the sentence cannot be tap-to-hear: one quiet speaker.
                listenButton(text: sentence, id: sentenceSpeechID, label: "Listen to the sentence", style: .plain)
            }
            HairlineDivider()
        }
    }

    @ViewBuilder
    private var summaryBlock: some View {
        if summary.isEmpty {
            // Nothing written yet (TASK-74): a spinner where the summary will appear.
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                // The summary grows word by word while it streams (TASK-73): the text view measures
                // its height again each time, so the line count follows the text. `.summary` reads its
                // Markdown, so **key words** show bold, not with their stars.
                SentenceTextView(text: summary, style: .summary, language: language, loadWordEntry: loadWordEntry)
                    .speechHighlight(isPlaying: speechPlayer.currentID == summarySpeechID)
                Text("In simple words")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
                actionRow
            }
            .padding(.top, Theme.Spacing.small)
        }
    }

    /// One quiet row of plain icons under the summary (TASK-126, mockup A, like the actions under a Claude reply):
    /// Listen to the summary, Like (finished answer only: the summary is what the Liked list shows), and Copy the
    /// original sentence. The plain icons keep their 44 pt tap target; the row starts at the text's left edge.
    private var actionRow: some View {
        HStack(spacing: 0) {
            listenButton(text: SummaryMarkup(summary).plainText, id: summarySpeechID, label: "Listen to the simple version", style: .plain)
            if translation != nil {
                LikeButton(item: SavedItem(kind: .sentence, text: savedText ?? sentence, preview: SummaryMarkup(summary).plainText))
            }
            IconButton(systemImage: didCopy ? "checkmark" : "doc.on.doc", label: "Copy the sentence", style: .plain, action: copy)
        }
        .padding(.leading, -(Theme.minTapTarget - 20) / 2)
    }

    /// Shown open (TASK-124): the fix matters more than the text the user typed.
    private func betterBlock(_ better: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
            Text("Better way to say it")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.textMuted)
            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                HStack(alignment: .top, spacing: Theme.Spacing.small) {
                    Text(BetterDiff(original: sentence, better: better).attributedString)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .speechHighlight(isPlaying: speechPlayer.currentID == betterSpeechID)
                        .padding(.top, Theme.Spacing.small)
                        // Tap the fixed text to hear it (TASK-126): no Listen button here.
                        .contentShape(Rectangle())
                        .onTapGesture { toggleSpeech(better, id: betterSpeechID) }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Plays the sound")
                    IconButton(
                        systemImage: didCopyBetter ? "checkmark" : "doc.on.doc",
                        label: "Copy the better version",
                        style: .plain
                    ) {
                        copyBetter(better)
                    }
                }
                if let betterWhy {
                    Text(betterWhy)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func listenButton(text: String, id: String, label: String, style: IconButton.Style = .circle) -> some View {
        IconButton(
            systemImage: speechPlayer.currentID == id ? "stop.fill" : "speaker.wave.2",
            label: speechPlayer.currentID == id ? "Stop" : label,
            style: style,
            isActive: speechPlayer.currentID == id
        ) {
            toggleSpeech(text, id: id)
        }
    }

    private func toggleSpeech(_ text: String, id: String) {
        if speechPlayer.currentID == id {
            speechPlayer.stop()
        } else {
            speechPlayer.speak(text, id: id)
        }
    }

    private func copyBetter(_ better: String) {
        Pasteboard.copy(better)
        didCopyBetter = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didCopyBetter = false
        }
    }

    private func copy() {
        Pasteboard.copy(sentence)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }
}

#Preview {
    SentenceCard(
        sentence: "The mist blurred the edges of the world, so the hikers turned back before noon.",
        summary: "The fog made everything hard to see, so the walkers went back before midday.",
        translation: "Sương mù làm mờ mọi thứ, nên những người đi bộ quay lại trước buổi trưa.",
        language: .vietnamese,
        loadWordEntry: { _ in .depend })
        .padding()
        .background(Theme.Colors.background)
        .environment(SpeechPlayer.silent())
}

#Preview("Better way to say it") {
    SentenceCard(
        sentence: "Please open the light, it's too dark.",
        summary: "You want someone to make the room bright.",
        translation: "Làm ơn bật đèn lên, tối quá.",
        language: .vietnamese,
        better: "Please turn on the light. It's too dark.",
        betterWhy: "In English you \"turn on\" a light, not \"open\" it.",
        loadWordEntry: { _ in .depend })
        .padding()
        .background(Theme.Colors.background)
        .environment(SpeechPlayer.silent())
}

#Preview("Long text: gist and bullets") {
    SentenceCard(
        sentence: "But the dev account getting banned would impact your career correct? Then in my mind, setting up "
            + "private distribution, speeding up rolling out updates and making things more efficient can only benefit you.",
        summary: "Your **career** is at risk if the developer account is banned.\n"
            + "- Use **private distribution** and faster updates to protect yourself.\n"
            + "- If the company keeps hiding **bad actions**, leave.",
        translation: "Nếu tài khoản bị cấm, sự nghiệp của bạn sẽ bị ảnh hưởng.",
        language: .vietnamese,
        loadWordEntry: { _ in .depend })
        .padding()
        .background(Theme.Colors.background)
        .environment(SpeechPlayer.silent())
}

#Preview("Waiting for the summary") {
    SentenceCard(
        sentence: "The mist blurred the edges of the world.",
        summary: "",
        translation: nil,
        language: .vietnamese)
        .padding()
        .background(Theme.Colors.background)
        .environment(SpeechPlayer.silent())
}
