//
//  CameraTextTests.swift
//  EnglishTranslationTests
//
//  Text mode of the camera (TASK-121.3): reading order, joining lines, picking lines, and the hand-off to the
//  normal flow. No camera and no Vision call.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import EnglishTranslation

private struct FakeReader: PhotoTextReading {
    var result: Result<[RecognizedLine], Error>

    func lines(in image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [RecognizedLine] {
        try result.get()
    }
}

private struct ReadFailed: Error {}

private func image() -> CGImage {
    let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    return context.makeImage()!
}

private func line(_ id: Int, _ text: String) -> RecognizedLine {
    RecognizedLine(id: id, text: text, box: CGRect(x: 0, y: 1 - Double(id) * 0.1, width: 1, height: 0.05))
}

struct CameraTextJoinTests {
    @Test func readingOrderIsTopToBottomThenLeftToRight() {
        let lines = CameraText.inReadingOrder([
            ("second", CGRect(x: 0.1, y: 0.5, width: 0.3, height: 0.05)),
            ("right", CGRect(x: 0.6, y: 0.8, width: 0.3, height: 0.05)),
            ("left", CGRect(x: 0.1, y: 0.81, width: 0.3, height: 0.05)),
        ])
        #expect(lines.map(\.text) == ["left", "right", "second"])
        #expect(lines.map(\.id) == [0, 1, 2])
    }

    @Test func cutWordsAreJoined() {
        #expect(CameraText.joined(["Please keep the exam-", "ple short."]) == "Please keep the example short.")
    }

    @Test func aDashBeforeACapitalStays() {
        #expect(CameraText.joined(["Hanoi -", "Saigon"]) == "Hanoi - Saigon")
    }

    @Test func spacesAreCollapsedAndEmptyLinesSkipped() {
        #expect(CameraText.joined(["  No   parking  ", "", "after 6 pm"]) == "No parking after 6 pm")
    }

    @Test func longTextIsCutAtASentenceEnd() {
        let text = CameraText.joined(["One two three. Four five six seven eight."], limit: 20)
        #expect(text == "One two three.")
    }
}

@MainActor
struct CameraTextStoreTests {
    @Test func photoLinesCanBePickedInReadingOrder() async {
        let store = CameraTextStore(reader: FakeReader(result: .success([line(0, "Wet floor."), line(1, "Mind the step.")])))
        await store.readPhoto(image())
        #expect(store.pickedText == nil)
        store.toggle(store.lines[1])
        store.toggle(store.lines[0])
        #expect(store.pickedText == "Wet floor. Mind the step.")
        store.toggle(store.lines[0])
        #expect(store.pickedText == "Mind the step.")
        #expect(store.allText == "Wet floor. Mind the step.")
    }

    @Test func aPhotoWithoutTextShowsAMessage() async {
        let store = CameraTextStore(reader: FakeReader(result: .success([])))
        await store.readPhoto(image())
        #expect(store.message == CameraTextStore.noTextMessage)
        #expect(store.allText == nil)
    }

    @Test func aFailedReadShowsTheSameMessage() async {
        let store = CameraTextStore(reader: FakeReader(result: .failure(ReadFailed())))
        await store.readPhoto(image())
        #expect(store.message == CameraTextStore.noTextMessage)
        #expect(store.isReading == false)
    }

    @Test func liveLinesDropPicksThatAreGone() {
        let store = CameraTextStore(reader: FakeReader(result: .success([])))
        store.showLive([line(0, "EXIT"), line(1, "Push")])
        store.toggle(store.lines[1])
        store.showLive([line(0, "EXIT")])
        #expect(store.pickedText == nil)
    }
}

/// Remembers the word it was asked; never answers a phrase, so a label with a space must not go down that path.
private final class LabelLookup: WordLooking, @unchecked Sendable {
    var asked: [String] = []
    var phraseAsked: [String] = []

    func lookUp(_ word: String) async throws -> WordEntry {
        asked.append(word)
        return WordEntry(word: word, ipa: nil, senses: [])
    }

    func phraseEntry(for phrase: String) async -> WordEntry? {
        phraseAsked.append(phrase)
        return nil
    }

    func terms(for word: String) async -> [Term] { [] }
}

@MainActor
struct CameraHandOffTests {
    @Test func aDishLabelOpensTheWordCardNotThePhrasePath() async {
        let lookup = LabelLookup()
        let store = TranslationStore(makeWordLookup: { lookup }, history: nil)
        await store.lookUpCameraLabel(" bánh mì ")
        #expect(lookup.asked == ["bánh mì"])
        #expect(lookup.phraseAsked.isEmpty)
        guard case let .loadedWord(entry) = store.state else { Issue.record("expected a word card"); return }
        #expect(entry.word == "bánh mì")
    }

    @Test func oneCameraWordAlsoOpensTheWordCard() async {
        let lookup = LabelLookup()
        let store = TranslationStore(makeWordLookup: { lookup }, history: nil)
        await store.explainFromCamera("EXIT")
        #expect(lookup.asked.first?.lowercased() == "exit")
    }
}
