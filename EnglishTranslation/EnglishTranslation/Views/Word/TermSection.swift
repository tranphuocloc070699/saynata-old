//
//  TermSection.swift
//  EnglishTranslation
//

import SwiftUI

/// Named things written like the word (TASK-119.6), below the senses: "swift" still means fast first, then
/// "Also a name: Swift, programming language". With no senses ("nuxtjs") the title is "A name".
/// Each term has its name, what it is, one simple sentence when the server has one, and icon-only buttons for the
/// official site and Wikipedia (CLAUDE.md "UI rule"). The links come from Wikidata, never from a model.
/// The developer chose no mockup for this section (2026-11-02); it uses the sense card's surface and text styles.
struct TermSection: View {
    let terms: [Term]
    /// True when the card has English senses above, so the title says "Also a name".
    var followsSenses = true

    @Environment(\.openURL) private var openURL

    private var title: String { followsSenses ? "Also a name" : "A name" }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            ForEach(terms) { term in
                termRow(term)
                if term.id != terms.last?.id {
                    Divider().overlay(Theme.Colors.hairline)
                }
            }
        }
        .padding(Theme.Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Theme.Colors.hairline, lineWidth: 1)
        }
    }

    private func termRow(_ term: Term) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.small) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                Text(term.name)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .textSelection(.enabled)
                if let field = term.field, !field.isEmpty {
                    Text(field)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                if let definition = term.simpleDefinition, !definition.isEmpty {
                    Text(definition)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .textSelection(.enabled)
                        .padding(.top, Theme.Spacing.xSmall)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let url = term.officialURL {
                IconButton(systemImage: "safari", label: "Open the official site of \(term.name)", size: .compact) {
                    openURL(url)
                }
            }
            if let url = term.wikipediaURL {
                IconButton(systemImage: "book", label: "Open \(term.name) on Wikipedia", size: .compact) {
                    openURL(url)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview("Below senses: swift") {
    ScrollView {
        TermSection(terms: [
            Term(name: "Swift", field: "general-purpose programming language by Apple",
                 simpleDefinition: "A language from Apple for making iPhone and Mac apps.",
                 officialUrl: "https://www.swift.org",
                 wikipediaUrl: "https://en.wikipedia.org/wiki/Swift_(programming_language)"),
        ])
        .padding()
    }
    .background(Theme.Colors.background)
}

#Preview("Alone: nuxtjs") {
    ScrollView {
        TermSection(terms: [
            Term(name: "Nuxt", field: "free and open source JavaScript framework", officialUrl: "https://nuxt.com",
                 wikipediaUrl: "https://en.wikipedia.org/wiki/Nuxt.js"),
        ], followsSenses: false)
        .padding()
    }
    .background(Theme.Colors.background)
}
