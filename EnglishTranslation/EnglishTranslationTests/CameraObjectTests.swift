//
//  CameraObjectTests.swift
//  EnglishTranslationTests
//
//  Object mode of the camera (TASK-121.4): label scores, the cascade, the store's throttle and steadiness, ask AI,
//  and the small JPEG. No model, no camera, no network.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import EnglishTranslation

/// Returns a fixed vector per call, in order (the last one repeats). Counts calls.
private final class FakeEmbedder: ImageEmbedding, @unchecked Sendable {
    var vectors: [[Float]]
    var calls = 0
    var error: Error?

    init(_ vectors: [[Float]]) { self.vectors = vectors }

    func embedding(for image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [Float] {
        if let error { throw error }
        defer { calls += 1 }
        return vectors[min(calls, vectors.count - 1)]
    }
}

private final class FakeIdentifier: VisionIdentifying, @unchecked Sendable {
    var result: Result<VisionAnswer, Error>
    var sent: [Data] = []

    init(_ result: Result<VisionAnswer, Error>) { self.result = result }

    func identify(jpeg: Data) async throws -> VisionAnswer {
        sent.append(jpeg)
        return try result.get()
    }
}

/// A clock the test moves by hand.
private final class FakeClock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 1000)
}

/// Three labels in 3 dimensions: desk = x, chair = y, phở = z (a dish).
private func index() throws -> LabelIndex {
    try LabelIndex(labels: ["desk", "chair", "phở"], food: [false, false, true], dish: [false, false, true],
                   dimension: 3, temperature: 100, vectors: [1, 0, 0, 0, 1, 0, 0, 0, 1])
}

/// The food layer knows two dishes: phở follows z, bún bò huế follows -x.
private func foodLayer() -> FoodLayer {
    FoodLayer(classes: ["phở", "bún bò huế"], weights: [[0, 0, 10], [-10, 0, 0]], bias: [0, 0])
}

private func unit(_ v: [Float]) -> [Float] {
    let length = sqrt(v.reduce(0) { $0 + $1 * $1 })
    return v.map { $0 / length }
}

private func image(width: Int = 8, height: Int = 8) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

struct LabelScoreTests {
    @Test func topLabelsAreSortedAndAddUpToOne() throws {
        let top = try index().top(3, for: unit([1, 0.2, 0]))
        #expect(top.map(\.label) == ["desk", "chair", "phở"])
        #expect(abs(top.map(\.score).reduce(0, +) - 1) < 0.001)
        #expect(top[0].score > 0.99) // temperature 100 makes a clear winner
    }

    @Test func wrongVectorLengthGivesNothing() throws {
        #expect(try index().top(3, for: [1, 0]).isEmpty)
        #expect(foodLayer().best(for: [1, 0]) == nil)
    }

    @Test func mismatchedFilesAreRejected() {
        #expect(throws: VisionLabelsError.self) {
            try LabelIndex(labels: ["a"], food: [false], dish: [false], dimension: 3, temperature: 100, vectors: [1, 0])
        }
    }

    @Test func foodLayerPicksTheDish() {
        let best = foodLayer().best(for: [0, 0, 1])
        #expect(best?.label == "phở")
        #expect(best?.isDish == true)
    }
}

struct ObjectCascadeTests {
    @Test func sureObjectShowsTheWord() throws {
        let guess = ObjectCascade(labels: try index(), food: foodLayer()).guess(for: [1, 0, 0])
        guard case let .sure(label) = guess else { Issue.record("expected sure, got \(guess)"); return }
        #expect(label.label == "desk")
    }

    @Test func foodOnTopAsksTheFoodLayer() throws {
        // Zero-shot says phở; the food layer is sure of phở too and wins.
        let guess = ObjectCascade(labels: try index(), food: foodLayer()).guess(for: [0, 0, 1])
        guard case let .sure(label) = guess else { Issue.record("expected sure, got \(guess)"); return }
        #expect(label.label == "phở")
        #expect(label.isDish)
    }

    @Test func unsureGivesThreeChips() throws {
        // Halfway between desk and chair: neither reaches 0.7.
        let guess = ObjectCascade(labels: try index(), food: nil).guess(for: unit([1, 1, 0]))
        guard case let .unsure(chips) = guess else { Issue.record("expected unsure, got \(guess)"); return }
        #expect(chips.count == 3)
        #expect(Set(chips.prefix(2).map(\.label)) == ["desk", "chair"])
    }

    @Test func unsureFoodLayerFallsBackToZeroShot() throws {
        // Food on top but the layer is unsure (z and -x equal): zero-shot phở is still sure on its own.
        let layer = FoodLayer(classes: ["phở", "bún bò huế"], weights: [[0, 0, 1], [0, 0, 1]], bias: [0, 0])
        let guess = ObjectCascade(labels: try index(), food: layer).guess(for: [0, 0, 1])
        guard case let .sure(label) = guess else { Issue.record("expected sure, got \(guess)"); return }
        #expect(label.label == "phở")
        #expect(label.score > 0.9)
    }
}

@MainActor
struct CameraObjectStoreTests {
    private func store(_ embedder: FakeEmbedder, identifier: FakeIdentifier? = nil, clock: FakeClock = FakeClock())
        -> CameraObjectStore {
        let labels = try! index()
        return CameraObjectStore(embedder: embedder, makeCascade: { ObjectCascade(labels: labels, food: foodLayer()) },
                                 identifier: identifier, now: { clock.now })
    }

    @Test func framesAreThrottled() async {
        let embedder = FakeEmbedder([[1, 0, 0]])
        let clock = FakeClock()
        let store = store(embedder, clock: clock)
        await store.receive(image())
        await store.receive(image()) // same moment: dropped
        clock.now += 0.1
        await store.receive(image()) // too soon: dropped
        clock.now += 0.4
        await store.receive(image())
        #expect(embedder.calls == 2)
    }

    @Test func newLabelWaitsForASecondFrame() async {
        let embedder = FakeEmbedder([[1, 0, 0], [0, 1, 0], [0, 1, 0]])
        let clock = FakeClock()
        let store = store(embedder, clock: clock)
        await store.receive(image())
        #expect(store.guess.sureLabel == "desk")
        clock.now += 1
        await store.receive(image())
        #expect(store.guess.sureLabel == "desk") // chair once: not yet
        clock.now += 1
        await store.receive(image())
        #expect(store.guess.sureLabel == "chair")
    }

    @Test func missingModelMakesObjectModeUnavailable() async {
        let embedder = FakeEmbedder([[1, 0, 0]])
        embedder.error = ImageEmbeddingError.modelMissing
        let store = store(embedder)
        await store.receive(image())
        #expect(store.isUnavailable)
        #expect(store.guess == .nothing)
    }

    @Test func askAISendsTheLatestFrameAndReturnsTheLabel() async {
        let identifier = FakeIdentifier(.success(VisionAnswer(label: " bánh mì ", kind: .dish, confidence: 0.9)))
        let store = store(FakeEmbedder([unit([1, 1, 0])]), identifier: identifier)
        await store.receive(image(width: 2000, height: 1000))
        let label = await store.askAI()
        #expect(label == "bánh mì")
        #expect(identifier.sent.count == 1)
        #expect(store.isAsking == false)
    }

    @Test func askAIShowsTheSignInMessage() async {
        let store = store(FakeEmbedder([[1, 0, 0]]), identifier: FakeIdentifier(.failure(BackendError.signInRequired)))
        await store.receive(image())
        #expect(await store.askAI() == nil)
        #expect(store.message == BackendError.signInRequired.errorDescription)
    }

    @Test func askAIWithoutAFrameSendsNothing() async {
        let identifier = FakeIdentifier(.success(VisionAnswer(label: "desk", kind: .object, confidence: 1)))
        let store = store(FakeEmbedder([[1, 0, 0]]), identifier: identifier)
        #expect(await store.askAI() == nil)
        #expect(identifier.sent.isEmpty)
    }

    @Test func resetForgetsTheFrame() async {
        let identifier = FakeIdentifier(.success(VisionAnswer(label: "desk", kind: .object, confidence: 1)))
        let store = store(FakeEmbedder([[1, 0, 0]]), identifier: identifier)
        await store.receive(image())
        store.reset()
        #expect(await store.askAI() == nil)
        #expect(store.guess == .nothing)
    }
}

struct SmallJPEGTests {
    @Test func longSideIsAtMost768() {
        #expect(SmallJPEG.targetSize(width: 4032, height: 3024) == (768, 576))
        #expect(SmallJPEG.targetSize(width: 1000, height: 3000) == (256, 768))
        #expect(SmallJPEG.targetSize(width: 500, height: 300) == (500, 300)) // never scaled up
    }

    @Test func makesAJPEG() throws {
        let data = try #require(SmallJPEG.make(from: image(width: 1600, height: 1200)))
        #expect(data.starts(with: [0xFF, 0xD8])) // JPEG start marker
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let size = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(size[kCGImagePropertyPixelWidth] as? Int == 768)
    }

    @Test func multipartBodyHasTheImageField() {
        let body = String(decoding: MultipartBody.image(Data("JPEG".utf8), field: "image", boundary: "b"), as: UTF8.self)
        #expect(body.contains("name=\"image\"; filename=\"photo.jpg\""))
        #expect(body.contains("Content-Type: image/jpeg\r\n\r\nJPEG\r\n--b--"))
    }
}

private extension ObjectGuess {
    var sureLabel: String? {
        if case let .sure(label) = self { return label.label }
        return nil
    }
}
