//
//  CameraText.swift
//  EnglishTranslation
//
//  Text mode of the camera screen (TASK-121.3): lines read from a photo (Vision) or the live camera (VisionKit),
//  which lines the user picked, and the text that goes into the normal sentence flow. No new LLM prompt.
//

import CoreGraphics
import Foundation
import ImageIO
import Observation
import Vision

/// One line of text the camera or a photo gave, with where it is (0...1, origin bottom left, like Vision).
struct RecognizedLine: Equatable, Identifiable, Sendable {
    let id: Int
    let text: String
    let box: CGRect
}

/// Reads the lines of text in a photo. Behind a protocol so tests use a fake.
protocol PhotoTextReading: Sendable {
    func lines(in image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [RecognizedLine]
}

/// iOS 18 Vision `RecognizeTextRequest`, accurate level, with language correction. Vision finds the language itself
/// (TASK-121.6): text in Vietnamese or Korean goes to the sentence flow, which gives the English version and its simple
/// English explanation (prompt v12+), so nothing else changes.
struct VisionTextReader: PhotoTextReading {
    func lines(in image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [RecognizedLine] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.recognitionLanguages = CameraText.languages.map { Locale.Language(identifier: $0) }
        let observations = try await request.perform(on: image, orientation: orientation)
        let texts = observations.compactMap { observation -> (String, CGRect)? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return (text, observation.boundingBox.cgRect)
        }
        return CameraText.inReadingOrder(texts)
    }
}

enum CameraText {
    /// The languages the camera reads: English first, then the app's target languages (Vision and VisionKit codes).
    static let languages = ["en-US", "vi-VT", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "fr-FR", "es-ES", "de-DE"]

    /// Top to bottom, then left to right; ids follow that order.
    static func inReadingOrder(_ texts: [(String, CGRect)]) -> [RecognizedLine] {
        let sorted = texts.sorted { a, b in
            // Lines whose middles are within half a line height count as one row.
            let rowGap = min(a.1.height, b.1.height) / 2
            if abs(a.1.midY - b.1.midY) > rowGap { return a.1.midY > b.1.midY }
            return a.1.minX < b.1.minX
        }
        return sorted.enumerated().map { RecognizedLine(id: $0.offset, text: $0.element.0, box: $0.element.1) }
    }

    /// The lines as one text for the sentence flow: a word cut at a line end ("exam-" + "ple") is joined, other line
    /// breaks become spaces, spaces are collapsed. Kept under the input limit, cut at a sentence end when possible.
    static func joined(_ lines: [String], limit: Int = TranslationStore.maxInputLength) -> String {
        var text = ""
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if text.hasSuffix("-"), let first = line.first, first.isLowercase {
                text.removeLast()
                text += line
            } else {
                text += text.isEmpty ? line : " " + line
            }
        }
        text = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit))
        if let end = head.lastIndex(where: { ".!?".contains($0) }), head.distance(from: head.startIndex, to: end) > limit / 3 {
            return String(head[...end])
        }
        return head.trimmingCharacters(in: .whitespaces)
    }
}

/// The lines on screen and the ones the user tapped.
@Observable
@MainActor
final class CameraTextStore {
    private(set) var lines: [RecognizedLine] = []
    private(set) var picked: Set<Int> = []
    private(set) var isReading = false
    /// Shown when a photo has no text or reading failed.
    private(set) var message: String?

    private let reader: any PhotoTextReading

    init(reader: any PhotoTextReading = VisionTextReader()) {
        self.reader = reader
    }

    static let noTextMessage = "No text found in this photo."

    /// Reads a library photo. The old lines and picks are cleared first.
    func readPhoto(_ image: CGImage, orientation: CGImagePropertyOrientation = .up) async {
        isReading = true
        message = nil
        picked = []
        defer { isReading = false }
        do {
            lines = try await reader.lines(in: image, orientation: orientation)
            if lines.isEmpty { message = Self.noTextMessage }
        } catch {
            lines = []
            message = Self.noTextMessage
        }
    }

    /// Live text from the camera: the newest lines replace the old ones; picks of lines that are gone are dropped.
    func showLive(_ newLines: [RecognizedLine]) {
        lines = newLines
        picked = picked.filter { id in newLines.contains { $0.id == id } }
        message = nil
    }

    func toggle(_ line: RecognizedLine) {
        if picked.contains(line.id) { picked.remove(line.id) } else { picked.insert(line.id) }
    }

    /// The "all text" button: picks every line, or clears the picks when all are picked already.
    func toggleAll() {
        let all = Set(lines.map(\.id))
        picked = picked == all ? [] : all
    }

    /// The text of the picked lines in reading order, or nil when none is picked.
    var pickedText: String? {
        let chosen = lines.filter { picked.contains($0.id) }.map(\.text)
        let text = CameraText.joined(chosen)
        return text.isEmpty ? nil : text
    }

    /// "All text": every line, or nil when there is none.
    var allText: String? {
        let text = CameraText.joined(lines.map(\.text))
        return text.isEmpty ? nil : text
    }

    func clear() {
        lines = []
        picked = []
        message = nil
    }
}
