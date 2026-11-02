//
//  ObjectCascade.swift
//  EnglishTranslation
//
//  Decides what object mode shows for one image vector (TASK-121.4). Thresholds and order come from the TASK-120
//  measurements in scripts/vision_spike/README.md.
//

import Foundation

/// What the camera shows for one frame.
enum ObjectGuess: Equatable, Sendable {
    /// Sure enough to show one label. Tapping it opens the word card.
    case sure(LabelScore)
    /// Not sure: the best three labels as chips, plus the "ask AI" button.
    case unsure([LabelScore])
    /// Nothing to show yet (no labels, or the model failed).
    case nothing
}

struct ObjectCascade: Sendable {
    /// 0.7: zero-shot is right 71% of the time above it (objects), the food layer 98% (dishes).
    static let sureScore: Float = 0.7
    static let chipCount = 3

    let labels: LabelIndex
    let food: FoodLayer?

    func guess(for embedding: [Float]) -> ObjectGuess {
        let top = labels.top(5, for: embedding)
        guard let best = top.first else { return .nothing }

        // b. A food word or a dish on top: the trained food layer knows the 30 dishes much better.
        if best.isFood || best.isDish, let dish = food?.best(for: embedding), dish.score >= Self.sureScore {
            return .sure(dish)
        }
        // c. Zero-shot is sure on its own.
        if best.score >= Self.sureScore {
            return .sure(best)
        }
        // d. Not sure: top 3 as chips (top-5 holds the right word 77% of the time for objects).
        return .unsure(Array(top.prefix(Self.chipCount)))
    }
}
