//
//  SettingsLegalLinksTests.swift
//  EnglishTranslationTests
//

import SwiftUI
import Testing
@testable import EnglishTranslation

/// TASK-112.1: the links under the Settings cards open the website's privacy policy and terms (TASK-102.4).
struct SettingsLegalLinksTests {
    @Test func privacyPolicyLinkOpensTheWebsitePage() {
        #expect(SettingsView<EmptyView>.privacyPolicyURL.absoluteString == "https://saynata.com/privacy")
    }

    @Test func termsLinkOpensTheWebsitePage() {
        #expect(SettingsView<EmptyView>.termsURL.absoluteString == "https://saynata.com/terms")
    }
}
