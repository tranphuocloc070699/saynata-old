//
//  CameraPanels.swift
//  EnglishTranslation
//
//  The bottom card of the camera screen (mockup approved 2026-11-02): text mode shows the picked text with
//  "all text" and Explain; object mode shows the sure label, or three chips and "ask AI".
//

import SwiftUI

/// Small uppercase heading of the bottom card.
private struct PanelCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textMuted)
    }
}

/// A red line with an icon, like the sign-in sheet's errors.
private struct PanelMessage: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.circle")
            .font(.footnote)
            .foregroundStyle(Theme.Colors.error)
    }
}

struct CameraTextPanel: View {
    let store: CameraTextStore
    /// Live text is not available (simulator, older phones): ask for a photo instead.
    var liveTextMissing = false
    /// Some lines show English over another language (TASK-121.7).
    var hasEnglish = false
    let onExplain: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            PanelCaption(text: caption)
            if let message = store.message {
                PanelMessage(text: message)
            }
            HStack(spacing: Theme.Spacing.medium) {
                if store.isReading { ProgressView().frame(width: Theme.minTapTarget, height: Theme.minTapTarget) }
                Spacer()
                IconButton(systemImage: "text.justify.left", label: "Explain all text", isProminent: true) {
                    if let text = store.allText { onExplain(text) }
                }
                .disabled(store.allText == nil)
                .opacity(store.allText == nil ? 0.4 : 1)
            }
        }
    }

    private var caption: String {
        if store.selectedLine != nil { return "Tap outside to close" }
        if liveTextMissing && store.lines.isEmpty { return "Live text is not available here. Choose a photo." }
        if store.lines.isEmpty { return "Point the camera at text" }
        return hasEnglish ? "Shown in English · Tap a line to see what it means" : "Tap a line to see what it means"
    }
}

struct CameraObjectPanel: View {
    let store: CameraObjectStore
    let onLabel: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            switch store.guess {
            case let .sure(label):
                PanelCaption(text: "I think this is")
                sureRow(label)
            case let .unsure(chips):
                PanelCaption(text: "Is it one of these?")
                HStack(spacing: Theme.Spacing.small) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.small) {
                            ForEach(chips, id: \.label) { chip in labelChip(chip) }
                        }
                    }
                    askAIButton
                }
            case .nothing:
                PanelCaption(text: store.isUnavailable
                             ? "Naming things is not available on this phone. Text mode still works."
                             : "Point the camera at a thing")
            }
            if let message = store.message {
                PanelMessage(text: message)
            }
        }
    }

    private func sureRow(_ label: LabelScore) -> some View {
        Button { onLabel(label.label) } label: {
            HStack(spacing: Theme.Spacing.medium) {
                Text(label.label)
                    .font(.system(.title, design: .serif).weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                if label.isDish {
                    Text("dish")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, Theme.Spacing.medium)
                        .padding(.vertical, Theme.Spacing.xSmall)
                        .background(Theme.Colors.chipFill, in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.large)
            .padding(.vertical, Theme.Spacing.medium)
            .frame(minHeight: Theme.minTapTarget)
            .background(Theme.Colors.meaningBlock, in: RoundedRectangle(cornerRadius: Theme.Radius.block))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label.label), open the word card")
    }

    /// A label chip: its text is the answer itself, so it keeps the word (like the "did you mean" chips).
    private func labelChip(_ chip: LabelScore) -> some View {
        Button { onLabel(chip.label) } label: {
            Text(chip.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.large)
                .frame(minHeight: Theme.minTapTarget)
                .background(Theme.Colors.chipFill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the word card")
    }

    @ViewBuilder
    private var askAIButton: some View {
        if store.isAsking {
            ProgressView()
                .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                .accessibilityLabel("Asking AI")
        } else {
            IconButton(systemImage: "sparkles", label: "Ask AI what this is", isProminent: true) {
                Task {
                    if let label = await store.askAI() { onLabel(label) }
                }
            }
        }
    }
}
