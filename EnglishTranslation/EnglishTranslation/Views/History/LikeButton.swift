//
//  LikeButton.swift
//  EnglishTranslation
//

import SwiftUI

/// The star on a word header or a sentence card (TASK-93.2). Icon only.
/// `.plain` (word header and sentence card, TASK-127 mockup B): a rounded outline star, filled in the accent colour
/// when liked; liking plays a short "saved" animation (the star pops away, a check mark draws itself, the filled
/// star springs back). `.circle` (the selected-text panel, among other round buttons): the SF Symbol in an `IconButton`.
/// A guest gets the sign-in sheet. Hidden when the screen has no `LikedStore`.
struct LikeButton: View {
    let item: SavedItem
    var style: IconButton.Style = .plain
    @Environment(LikedStore.self) private var liked: LikedStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Grows with Dynamic Type, like the `.body` SF Symbols next to it.
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20
    /// Set by a tap, so the check plays only for the user's own like (it may land after sign-in), not a sync.
    @State private var didTap = false
    @State private var isShowingCheck = false
    @State private var checkProgress: CGFloat = 0

    var body: some View {
        if let liked {
            let isLiked = liked.isLiked(item)
            if style == .circle {
                IconButton(systemImage: isLiked ? "star.fill" : "star", label: isLiked ? "Unlike" : "Like") {
                    Task { await liked.toggle(item) }
                }
            } else {
                Button {
                    didTap = true
                    Task { await liked.toggle(item) }
                } label: {
                    icon(isLiked: isLiked)
                        .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isLiked ? "Unlike" : "Like")
                .onChange(of: isLiked) { _, nowLiked in
                    if didTap, nowLiked { playCheck() }
                    didTap = false
                }
            }
        }
    }

    private func icon(isLiked: Bool) -> some View {
        let lineWidth = iconSize * 0.08
        return ZStack {
            RoundedStar()
                .fill(isLiked ? Theme.Colors.accent : Color.clear)
                .stroke(isLiked ? Theme.Colors.accent : Theme.Colors.textSecondary,
                        style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
                .scaleEffect(isShowingCheck ? 0.3 : 1)
                .opacity(isShowingCheck ? 0 : 1)
            CheckMarkShape()
                .trim(from: 0, to: checkProgress)
                .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: lineWidth * 1.25, lineCap: .round, lineJoin: .round))
                .opacity(isShowingCheck ? 1 : 0)
        }
        .frame(width: iconSize, height: iconSize)
    }

    /// Star out, check draws in, then the filled star springs back. Skipped with Reduce Motion.
    private func playCheck() {
        guard !reduceMotion else { return }
        withAnimation(.easeIn(duration: 0.15)) { isShowingCheck = true }
        withAnimation(.easeOut(duration: 0.3).delay(0.15)) { checkProgress = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                isShowingCheck = false
            } completion: {
                checkProgress = 0
            }
        }
    }
}
