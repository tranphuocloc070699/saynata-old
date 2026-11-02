//
//  ImageEmbedding.swift
//  EnglishTranslation
//
//  The image vector for object mode (TASK-121.4): MobileCLIP2 as Core ML on the Neural Engine. Behind a protocol so
//  tests use a fake and never load the model.
//

import CoreGraphics
import CoreML
import Foundation
import ImageIO
import Vision

/// Turns a picture into a vector of length 1 that can be compared with the label vectors.
protocol ImageEmbedding: Sendable {
    func embedding(for image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [Float]
}

enum ImageEmbeddingError: Error, Equatable {
    case modelMissing
    case badOutput
}

/// MobileCLIPImage.mlpackage, built by scripts/vision_spike/build_coreml.py. Xcode compiles it to .mlmodelc.
/// The model is loaded on first use (about a second), off the main thread.
actor MobileCLIPEmbedder: ImageEmbedding {
    private var model: MLModel?
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func embedding(for image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [Float] {
        let model = try loadedModel()
        guard let constraint = model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint else {
            throw ImageEmbeddingError.badOutput
        }
        // Center crop, then scale to 256x256, like the PyTorch preprocessing the label thresholds were measured with.
        let input = try MLFeatureValue(cgImage: image, orientation: orientation, constraint: constraint, options: [
            .cropAndScale: VNImageCropAndScaleOption.centerCrop.rawValue,
        ])
        let provider = try MLDictionaryFeatureProvider(dictionary: ["image": input])
        let output = try await model.prediction(from: provider)
        guard let array = output.featureValue(for: "embedding")?.multiArrayValue else {
            throw ImageEmbeddingError.badOutput
        }
        return (0..<array.count).map { array[$0].floatValue }
    }

    private func loadedModel() throws -> MLModel {
        if let model { return model }
        guard let url = bundle.url(forResource: "MobileCLIPImage", withExtension: "mlmodelc") else {
            throw ImageEmbeddingError.modelMissing
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all // the Neural Engine when it can
        let loaded = try MLModel(contentsOf: url, configuration: configuration)
        model = loaded
        return loaded
    }
}
