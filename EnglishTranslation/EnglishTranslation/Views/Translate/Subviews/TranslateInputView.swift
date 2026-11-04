//
//  TranslateInputView.swift
//  EnglishTranslation
//

import SwiftUI

/// The composer card (TASK-97): the text on top; below it the target-language chip on the left,
/// the character counter (only near the limit), the Clear (x) button (only with text, TASK-127) and the round
/// Explain button on the right.
struct TranslateInputView: View {
    @Environment(TranslationStore.self) private var store
    /// Owned by the screen, so a tap outside the box can hide the keyboard.
    var isFocused: FocusState<Bool>.Binding

    /// The counter stays hidden until the text is close to the limit.
    static let counterStart = 450

    var body: some View {
        @Bindable var store = store

        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            // 2 lines when empty, grows to 6, then scrolls.
            TextField("Type a word or a sentence", text: $store.inputText, axis: .vertical)
                .font(.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2...6)
                .focused(isFocused)

            HStack(spacing: Theme.Spacing.medium) {
                LanguageChip()
                Spacer()
                if store.inputLength >= Self.counterStart {
                    CharacterCounter(count: store.inputLength, limit: TranslationStore.maxInputLength)
                }
                // Always in the row, only hidden when empty: the row never changes size while typing,
                // so the language menu next to it is not laid out again (it was clipped, "ietnamese").
                IconButton(systemImage: "xmark", label: "Clear", style: .plain) {
                    store.inputText = ""
                }
                .opacity(store.inputText.isEmpty ? 0 : 1)
                .disabled(store.inputText.isEmpty)
                .accessibilityHidden(store.inputText.isEmpty)
                IconButton(systemImage: "arrow.up", label: "Explain", isProminent: true) {
                    isFocused.wrappedValue = false
                    Task { await store.translate() }
                }
                .disabled(!store.canTranslate)
                .opacity(store.canTranslate ? 1 : 0.4)
            }
        }
        .padding(Theme.Spacing.large)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay {
            // Accent only while the box has the keyboard (design-system rule 3: focus).
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(isFocused.wrappedValue ? Theme.Colors.accent : Theme.Colors.hairline, lineWidth: 1)
        }
    }
}

/// The target-language picker, drawn as a small pill (a menu).
/// Its own view that reads only `targetLanguage`, so typing in the box does not redraw the menu.
private struct LanguageChip: View {
    @Environment(TranslationStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Menu {
            Picker("Translate into", selection: $store.targetLanguage) {
                ForEach(TargetLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xSmall) {
                Text(store.targetLanguage.title)
                Image(systemName: "chevron.down")
                    .imageScale(.small)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.medium)
            .padding(.vertical, Theme.Spacing.small)
            .background(Theme.Colors.chipFill, in: Capsule())
        }
        .fixedSize()
        .layoutPriority(1)
        .accessibilityLabel("Translate into")
        .accessibilityValue(store.targetLanguage.title)
    }
}

#Preview {
    @Previewable @FocusState var focused: Bool
    TranslateInputView(isFocused: $focused)
        .padding()
        .background(Theme.Colors.background)
        .environment(TranslationStore())
}
