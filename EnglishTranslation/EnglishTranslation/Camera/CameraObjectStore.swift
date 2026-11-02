//
//  CameraObjectStore.swift
//  EnglishTranslation
//
//  Object mode of the camera screen (TASK-121.4). Frames come in fast; this store looks at a few per second, runs the
//  cascade and keeps the label steady. "Ask AI" sends the newest frame to the backend.
//

import CoreGraphics
import Foundation
import ImageIO
import Observation

@Observable
@MainActor
final class CameraObjectStore {
    /// What the screen shows over the camera.
    private(set) var guess: ObjectGuess = .nothing
    /// True while "ask AI" waits for the backend.
    private(set) var isAsking = false
    /// A short message under the chips, for example the sign-in or daily-limit text. Nil when there is none.
    private(set) var message: String?
    /// Set when the model files are missing or broken; the screen then offers only text mode.
    private(set) var isUnavailable = false

    /// At most this many frames are analysed per second; the others are dropped.
    static let framesPerSecond: Double = 3
    /// A new label must win this many analyses in a row before it replaces the one on screen, so it does not flicker.
    static let stableCount = 2

    private let embedder: any ImageEmbedding
    private let makeCascade: @Sendable () throws -> ObjectCascade
    private let identifier: (any VisionIdentifying)?
    private let now: () -> Date

    private var cascade: ObjectCascade?
    private var isAnalysing = false
    private var lastAnalysis: Date?
    private var pending: (guess: ObjectGuess, count: Int)?
    private var latestFrame: (image: CGImage, orientation: CGImagePropertyOrientation)?

    init(embedder: any ImageEmbedding,
         makeCascade: @escaping @Sendable () throws -> ObjectCascade,
         identifier: (any VisionIdentifying)?,
         now: @escaping () -> Date = Date.init) {
        self.embedder = embedder
        self.makeCascade = makeCascade
        self.identifier = identifier
        self.now = now
    }

    /// The real model and label files from the app bundle.
    static func live(identifier: (any VisionIdentifying)?) -> CameraObjectStore {
        CameraObjectStore(embedder: MobileCLIPEmbedder(), makeCascade: {
            ObjectCascade(labels: try LabelIndex.load(), food: try? FoodLayer.load())
        }, identifier: identifier)
    }

    /// A new camera frame. Ignored while the last one is still being analysed, or when it came too soon.
    func receive(_ image: CGImage, orientation: CGImagePropertyOrientation = .right) async {
        latestFrame = (image, orientation)
        guard !isAnalysing, !isUnavailable else { return }
        let time = now()
        if let lastAnalysis, time.timeIntervalSince(lastAnalysis) < 1 / Self.framesPerSecond { return }
        lastAnalysis = time
        isAnalysing = true
        defer { isAnalysing = false }

        do {
            let cascade = try loadedCascade()
            let vector = try await embedder.embedding(for: image, orientation: orientation)
            show(cascade.guess(for: vector))
        } catch {
            isUnavailable = true
            guess = .nothing
        }
    }

    /// A photo picked from the library: analysed once, no throttle or steadiness wait.
    func analysePhoto(_ image: CGImage, orientation: CGImagePropertyOrientation = .up) async {
        latestFrame = (image, orientation)
        pending = nil
        do {
            let cascade = try loadedCascade()
            guess = cascade.guess(for: try await embedder.embedding(for: image, orientation: orientation))
        } catch {
            isUnavailable = true
            guess = .nothing
        }
    }

    /// "Ask AI": sends the newest frame (max 768 px JPEG) to the backend. Returns the label to open as a word card,
    /// or nil (the message says why). One request at a time.
    func askAI() async -> String? {
        guard !isAsking, let identifier, let frame = latestFrame,
              let jpeg = SmallJPEG.make(from: frame.image, orientation: frame.orientation) else { return nil }
        isAsking = true
        message = nil
        defer { isAsking = false }
        do {
            let answer = try await identifier.identify(jpeg: jpeg)
            let label = answer.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else {
                message = Self.noAnswerMessage
                return nil
            }
            return label
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? Self.noAnswerMessage
            return nil
        }
    }

    /// The camera was closed: forget the frame, so a later "ask AI" never sends an old picture.
    func reset() {
        guess = .nothing
        pending = nil
        latestFrame = nil
        lastAnalysis = nil
        message = nil
    }

    static let noAnswerMessage = "Saynata could not name this. Try again closer, or in better light."

    private func loadedCascade() throws -> ObjectCascade {
        if let cascade { return cascade }
        let made = try makeCascade()
        cascade = made
        return made
    }

    /// Shows a new guess only after it wins `stableCount` analyses in a row. The first guess shows at once.
    private func show(_ new: ObjectGuess) {
        guard guess != .nothing else {
            guess = new
            return
        }
        guard Self.sameLabel(new, guess) == false else {
            guess = new // same label: refresh the score and the chips
            pending = nil
            return
        }
        if let pending, Self.sameLabel(pending.guess, new) {
            let count = pending.count + 1
            if count >= Self.stableCount {
                guess = new
                self.pending = nil
            } else {
                self.pending = (new, count)
            }
        } else {
            pending = (new, 1)
            if Self.stableCount <= 1 { guess = new; pending = nil }
        }
    }

    /// Two guesses name the same thing: both sure of one label, or both unsure with the same first chip.
    private static func sameLabel(_ a: ObjectGuess, _ b: ObjectGuess) -> Bool {
        switch (a, b) {
        case let (.sure(x), .sure(y)): x.label == y.label
        case let (.unsure(x), .unsure(y)): x.first?.label == y.first?.label
        case (.nothing, .nothing): true
        default: false
        }
    }
}
