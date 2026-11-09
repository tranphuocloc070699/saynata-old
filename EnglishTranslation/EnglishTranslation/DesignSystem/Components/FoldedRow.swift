//
//  FoldedRow.swift
//  EnglishTranslation
//

import SwiftUI

/// A row that opens and closes, such as "More examples", "How to use it" or "Vietnamese".
/// The parent owns `isExpanded`, so it can keep only one row open at a time.
/// The title is a section heading, not a button label, so it keeps its text (CLAUDE.md "UI rule").
struct FoldedRow<Content: View>: View {
    let title: String
    /// Shown after the title, for example "2". Optional.
    var count: Int?
    @Binding var isExpanded: Bool
    /// False for the target-language row: it is the last row of a card, so no line under it (TASK-127).
    var showsDivider = true
    /// Set on the target-language row where the user may pick another language (the share and translation sheet):
    /// the title becomes a menu of the languages, and the chevron still opens and closes the row.
    var language: Binding<TargetLanguage>?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language {
                HStack(spacing: Theme.Spacing.small) {
                    LanguageTitleMenu(language: language)
                    Spacer()
                    Button {
                        isExpanded.toggle()
                    } label: {
                        chevron
                            .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Hide \(title)" : "Show \(title)")
                }
            } else {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: Theme.Spacing.small) {
                        titleText
                        if let count {
                            Text("\(count)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }
                        Spacer()
                        chevron
                    }
                    .frame(minHeight: Theme.minTapTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(isExpanded ? "Open" : "Closed")
            }

            if isExpanded {
                content
                    .padding(.bottom, Theme.Spacing.medium)
            }

            if showsDivider {
                HairlineDivider()
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.Colors.textPrimary)
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.Colors.textSecondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
    }
}

/// The language name as a menu: "French ⌃⌄". A tap lists every language, with a check by the current one.
private struct LanguageTitleMenu: View {
    @Binding var language: TargetLanguage

    var body: some View {
        Menu {
            Picker("Language", selection: $language) {
                ForEach(TargetLanguage.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xSmall) {
                Text(language.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(minHeight: Theme.minTapTarget)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Language: \(language.title)")
        .accessibilityHint("Picks another language")
    }
}

#Preview("Language menu") {
    @Previewable @State var isExpanded = true
    @Previewable @State var language = TargetLanguage.vietnamese

    FoldedRow(title: language.title, isExpanded: $isExpanded, showsDivider: false, language: $language) {
        Text("Kỹ lưỡng, cẩn thận.")
    }
    .padding()
}

#Preview {
    @Previewable @State var isExpanded = true

    FoldedRow(title: "Vietnamese", isExpanded: $isExpanded) {
        Text("Kỹ lưỡng, cẩn thận.")
    }
    .padding()
}
