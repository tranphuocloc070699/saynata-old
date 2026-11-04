//
//  LikeButton.swift
//  EnglishTranslation
//

import SwiftUI

/// The star on a word header or a sentence card (TASK-93.2). Icon only: `star` when not liked, `star.fill` when liked.
/// A guest gets the sign-in sheet. Hidden when the screen has no `LikedStore`.
struct LikeButton: View {
    let item: SavedItem
    /// `.plain` in the quiet action row under a sentence summary (TASK-126, mockup A).
    var style: IconButton.Style = .circle
    @Environment(LikedStore.self) private var liked: LikedStore?

    var body: some View {
        if let liked {
            let isLiked = liked.isLiked(item)
            IconButton(
                systemImage: isLiked ? "star.fill" : "star",
                label: isLiked ? "Unlike" : "Like",
                style: style,
                isActive: isLiked
            ) {
                Task { await liked.toggle(item) }
            }
        }
    }
}
