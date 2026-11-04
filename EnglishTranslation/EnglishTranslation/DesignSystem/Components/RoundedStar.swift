//
//  RoundedStar.swift
//  EnglishTranslation
//

import SwiftUI

/// A five-point star with rounded points and inner corners (TASK-127). SF Symbols has no rounded star,
/// so the Like button draws this one. Each corner is an arc tangent to its two edges.
struct RoundedStar: Shape {
    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        // A star's points reach lower than its top point, so the centre sits a little below the middle.
        let center = CGPoint(x: rect.midX, y: rect.midY + size * 0.04)
        let outer = size * 0.5
        let inner = outer * 0.48
        let corners: [(point: CGPoint, radius: CGFloat)] = (0..<10).map { index in
            let angle = -CGFloat.pi / 2 + CGFloat(index) * .pi / 5
            let radius = index.isMultiple(of: 2) ? outer : inner
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            return (point, index.isMultiple(of: 2) ? size * 0.07 : size * 0.05)
        }

        var path = Path()
        let first = corners[0].point
        let last = corners[9].point
        path.move(to: CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2))
        for index in corners.indices {
            let next = corners[(index + 1) % corners.count].point
            path.addArc(tangent1End: corners[index].point, tangent2End: next, radius: corners[index].radius)
        }
        path.closeSubpath()
        return path
    }
}

/// A check mark drawn from left to right, so `.trim(from: 0, to: progress)` draws it like a pen.
struct CheckMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.17, y: rect.minY + rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.71))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.83, y: rect.minY + rect.height * 0.25))
        return path
    }
}

#Preview {
    HStack(spacing: Theme.Spacing.large) {
        RoundedStar().stroke(Theme.Colors.textSecondary, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
        RoundedStar().fill(Theme.Colors.accent)
        CheckMarkShape().stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }
    .frame(width: 160, height: 40)
    .padding()
}
