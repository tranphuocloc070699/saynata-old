//
//  VisionLabels.swift
//  EnglishTranslation
//
//  The labels the camera can name on the phone (TASK-121.4): dictionary nouns and 30 Vietnamese dishes, each with a
//  text vector made offline by scripts/vision_spike/build_coreml.py, plus the trained food layer for the dishes.
//

import Accelerate
import Foundation

/// One label with its score (0...1). Scores of one guess add up to 1 (softmax).
struct LabelScore: Equatable, Sendable {
    let label: String
    let score: Float
    /// A food word (WordNet noun.food) or a dish: the food layer gets a say.
    var isFood: Bool = false
    var isDish: Bool = false
}

enum VisionLabelsError: Error, Equatable {
    case missingFile(String)
    case badFile(String)
}

/// The zero-shot labels: softmax(temperature × cosine) of the image vector against every label vector.
struct LabelIndex: Sendable {
    let labels: [String]
    let food: [Bool]
    let dish: [Bool]
    let dimension: Int
    let temperature: Float
    /// labels.count × dimension, row by row.
    let vectors: [Float]

    init(labels: [String], food: [Bool], dish: [Bool], dimension: Int, temperature: Float, vectors: [Float]) throws {
        guard food.count == labels.count, dish.count == labels.count, vectors.count == labels.count * dimension else {
            throw VisionLabelsError.badFile("labels and vectors do not match")
        }
        self.labels = labels
        self.food = food
        self.dish = dish
        self.dimension = dimension
        self.temperature = temperature
        self.vectors = vectors
    }

    /// Reads labels.json and label_vectors.f16 (float16, little-endian) from the bundle.
    static func load(from bundle: Bundle = .main) throws -> LabelIndex {
        struct File: Decodable {
            let dimension: Int
            let temperature: Float
            let labels: [String]
            let food: [Bool]
            let dish: [Bool]
        }
        guard let jsonURL = bundle.url(forResource: "labels", withExtension: "json") else {
            throw VisionLabelsError.missingFile("labels.json")
        }
        guard let vectorURL = bundle.url(forResource: "label_vectors", withExtension: "f16") else {
            throw VisionLabelsError.missingFile("label_vectors.f16")
        }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: jsonURL))
        let data = try Data(contentsOf: vectorURL, options: .mappedIfSafe)
        let halves = data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: UInt16.self)).map { Float(Float16(bitPattern: UInt16(littleEndian: $0))) }
        }
        return try LabelIndex(labels: file.labels, food: file.food, dish: file.dish, dimension: file.dimension,
                              temperature: file.temperature, vectors: halves)
    }

    /// The best `count` labels for an image vector (length 1), best first.
    func top(_ count: Int, for embedding: [Float]) -> [LabelScore] {
        guard embedding.count == dimension, !labels.isEmpty else { return [] }
        // cosine = vectors · embedding (both have length 1)
        var cosines = [Float](repeating: 0, count: labels.count)
        vectors.withUnsafeBufferPointer { matrix in
            embedding.withUnsafeBufferPointer { vector in
                cosines.withUnsafeMutableBufferPointer { out in
                    vDSP_mmul(matrix.baseAddress!, 1, vector.baseAddress!, 1, out.baseAddress!, 1,
                              vDSP_Length(labels.count), 1, vDSP_Length(dimension))
                }
            }
        }
        let probabilities = Softmax.of(cosines.map { $0 * temperature })
        return probabilities.indices
            .sorted { probabilities[$0] > probabilities[$1] }
            .prefix(count)
            .map { LabelScore(label: labels[$0], score: probabilities[$0], isFood: food[$0], isDish: dish[$0]) }
    }
}

/// The trained layer for the 30 dishes: softmax(weights · embedding + bias).
struct FoodLayer: Sendable {
    let classes: [String]
    /// classes.count rows of `dimension` numbers.
    let weights: [[Float]]
    let bias: [Float]

    static func load(from bundle: Bundle = .main) throws -> FoodLayer {
        struct File: Decodable {
            let classes: [String]
            let weights: [[Float]]
            let bias: [Float]
        }
        guard let url = bundle.url(forResource: "food_layer", withExtension: "json") else {
            throw VisionLabelsError.missingFile("food_layer.json")
        }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        guard file.weights.count == file.classes.count, file.bias.count == file.classes.count else {
            throw VisionLabelsError.badFile("food_layer.json")
        }
        return FoodLayer(classes: file.classes, weights: file.weights, bias: file.bias)
    }

    /// The best dish and its score, or nil when the vector has the wrong length.
    func best(for embedding: [Float]) -> LabelScore? {
        guard let first = weights.first, first.count == embedding.count else { return nil }
        let logits = zip(weights, bias).map { row, b in vDSP.dot(row, embedding) + b }
        let probabilities = Softmax.of(logits)
        guard let index = probabilities.indices.max(by: { probabilities[$0] < probabilities[$1] }) else { return nil }
        return LabelScore(label: classes[index], score: probabilities[index], isFood: true, isDish: true)
    }
}

enum Softmax {
    static func of(_ values: [Float]) -> [Float] {
        guard let biggest = values.max() else { return [] }
        let exps = values.map { expf($0 - biggest) }
        let sum = exps.reduce(0, +)
        return exps.map { $0 / sum }
    }
}
