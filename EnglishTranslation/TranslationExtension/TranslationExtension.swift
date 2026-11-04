//
//  TranslationExtension.swift
//  TranslationExtension
//

import ExtensionKit
import SwiftUI
import TranslationUIProvider

/// The entry point of the translation extension (iOS 18.4 and later).
///
/// When Saynata is the default translation app (Settings, Apps, Default Apps, Translation), the system
/// "Translate" item on selected text in any app opens this extension. Apple's guide:
/// https://developer.apple.com/documentation/translationuiprovider/preparing-your-app-to-be-the-default-translation-app
@main
class TranslationExtension: TranslationUIProviderExtension {
    required init() {}

    var body: some TranslationUIProviderExtensionScene {
        TranslationUIProviderSelectedTextScene { context in
            TranslationSheetView(context: context)
        }
    }
}

/// Shows the same sheet as the share extension for the text the user selected. No Close button (the system draws its own X).
/// Saynata never replaces text with a translation. When the host lets it replace the selection (the user is writing,
/// for example a Telegram message), the sheet adds the Fix card: the user's own text with its mistakes fixed, in
/// English, and a button that puts it back (option A, 2026-11-02). Text the user is only reading gets no Fix card.
private struct TranslationSheetView: View {
    let context: TranslationUIProviderContext

    var body: some View {
        SelectedTextResultView(
            loadText: { context.inputText.map { String($0.characters) } ?? "" },
            onReplace: replace,
            source: .translateSheet)
    }

    /// Puts the fixed text in place of the selection and closes the sheet. Nil when the host does not allow it.
    private var replace: ((String) -> Void)? {
        guard context.allowsReplacement else { return nil }
        return { fixed in context.finish(translation: AttributedString(fixed)) }
    }
}
