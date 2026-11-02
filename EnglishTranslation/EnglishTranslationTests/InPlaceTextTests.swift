//
//  InPlaceTextTests.swift
//  EnglishTranslationTests
//
//  Text in place (TASK-121.7): English drawn over other-language lines, the eye button, and the explanation of a
//  tapped line. No camera, no Apple Translation, no network.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import EnglishTranslation

/// Vietnamese when the text has a Vietnamese letter, else English.
private struct FakeDetector: LanguageDetecting {
    func language(of text: String) -> String? {
        text.contains(where: { "ăâđêôơưạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ".contains($0) }) ? "vi" : "en"
    }
}

/// Answers from a fixed list, and remembers what it was asked.
private final class FakeEnglish: EnglishMaking {
    var answers: [String: String]
    var asked: [[String]] = []
    var fails = false

    init(_ answers: [String: String]) { self.answers = answers }

    func english(for texts: [String]) async throws -> [String] {
        asked.append(texts)
        if fails { throw CancellationError() }
        return texts.map { answers[$0] ?? "" }
    }
}

private struct FakeExplainer: Translating {
    var result: Result<Explanation, Error>

    func explain(_ text: String, translatingTo language: TargetLanguage) async throws -> Explanation {
        try result.get()
    }
}

private struct NoReader: PhotoTextReading {
    func lines(in image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [RecognizedLine] { [] }
}

private func line(_ id: Int, _ text: String) -> RecognizedLine {
    RecognizedLine(id: id, text: text, box: CGRect(x: 0.1, y: 0.8 - Double(id) * 0.1, width: 0.5, height: 0.05))
}

@MainActor
struct InPlaceTextTests {
    private func store(_ explainer: FakeExplainer? = nil) -> CameraTextStore {
        CameraTextStore(reader: NoReader(), detector: FakeDetector(), explainer: explainer)
    }

    @Test func otherLanguageLinesAreQueuedForEnglish() {
        let store = store()
        store.showLive([line(0, "Không đỗ xe"), line(1, "EXIT")])
        #expect(store.englishRequest?.language == "vi")
        #expect(store.hasEnglishOverlay == false)
    }

    @Test func englishIsDrawnOverTheLine() async {
        let store = store()
        store.showLive([line(0, "Không đỗ xe"), line(1, "EXIT")])
        let maker = FakeEnglish(["Không đỗ xe": "No parking"])
        await store.makeEnglish(with: maker)
        #expect(maker.asked == [["Không đỗ xe"]]) // the English line is not sent
        #expect(store.overlayText(for: store.lines[0]) == "No parking")
        #expect(store.overlayText(for: store.lines[1]) == nil)
        #expect(store.englishRequest == nil)
        #expect(store.hasEnglishOverlay)
    }

    @Test func aLineIsCheckedOnlyOnce() async {
        let store = store()
        let maker = FakeEnglish(["Không đỗ xe": "No parking"])
        store.showLive([line(0, "Không đỗ xe")])
        await store.makeEnglish(with: maker)
        store.showLive([line(0, "Không đỗ xe")]) // the next live frame
        #expect(store.englishRequest == nil)
        #expect(maker.asked.count == 1)
    }

    @Test func theEyeButtonShowsTheOriginal() async {
        let store = store()
        store.showLive([line(0, "Không đỗ xe")])
        await store.makeEnglish(with: FakeEnglish(["Không đỗ xe": "No parking"]))
        store.showsOriginal = true
        #expect(store.overlayText(for: store.lines[0]) == nil)
    }

    @Test func aFailedTranslationLeavesTheLineAsItIs() async {
        let store = store()
        store.showLive([line(0, "Không đỗ xe")])
        let maker = FakeEnglish([:])
        maker.fails = true
        await store.makeEnglish(with: maker)
        #expect(store.overlayText(for: store.lines[0]) == nil)
        #expect(store.englishRequest == nil)
    }

    @Test func tappingALineShowsItsExplanation() async {
        let answer = Explanation(meaning: "Don't leave a car here.", words: [], translation: "Không đỗ xe")
        let store = store(FakeExplainer(result: .success(answer)))
        store.showLive([line(0, "Không đỗ xe")])
        await store.select(store.lines[0], language: .vietnamese)
        #expect(store.selectedLine?.id == 0)
        #expect(store.explanation == .loaded(answer))
    }

    @Test func liveLinesStayStillWhileAnExplanationIsOpen() async {
        let answer = Explanation(meaning: "A way out.", words: [], translation: "")
        let store = store(FakeExplainer(result: .success(answer)))
        store.showLive([line(0, "EXIT")])
        await store.select(store.lines[0], language: .vietnamese)
        store.showLive([line(5, "PUSH")])
        #expect(store.lines.map(\.text) == ["EXIT"])
        store.closeExplanation()
        store.showLive([line(5, "PUSH")])
        #expect(store.lines.map(\.text) == ["PUSH"])
        #expect(store.explanation == .idle)
    }

    @Test func aSignInErrorIsShownInTheBubble() async {
        let store = store(FakeExplainer(result: .failure(BackendError.signInRequired)))
        store.showLive([line(0, "EXIT")])
        await store.select(store.lines[0], language: .vietnamese)
        #expect(store.explanation == .failed(BackendError.signInRequired.errorDescription ?? ""))
    }

    @Test func noExplainerGivesAMessage() async {
        let store = store()
        store.showLive([line(0, "EXIT")])
        await store.select(store.lines[0], language: .vietnamese)
        #expect(store.explanation == .failed(CameraTextStore.noExplanationMessage))
    }

    @Test func calloutGoesAboveALowLine() {
        let size = CGSize(width: 390, height: 844)
        #expect(CalloutPlacement.place(lineRect: CGRect(x: 0, y: 100, width: 100, height: 20), in: size).above == false)
        #expect(CalloutPlacement.place(lineRect: CGRect(x: 0, y: 700, width: 100, height: 20), in: size).above == true)
    }
}
