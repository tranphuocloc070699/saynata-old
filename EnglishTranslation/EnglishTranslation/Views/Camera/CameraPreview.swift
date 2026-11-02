//
//  CameraPreview.swift
//  EnglishTranslation
//
//  What the back camera sees, full screen, for object mode (TASK-121.4).
//

import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        // swiftlint:disable:next force_cast
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

/// Draws over the lines of text (TASK-121.7): English on a white box over a line in another language, and an accent
/// outline on the tapped line. Boxes are 0...1 with the origin at the bottom left.
struct TextLinesOverlay: View {
    let lines: [RecognizedLine]
    /// The English to draw over a line, or nil.
    let english: (RecognizedLine) -> String?
    var selectedID: Int?
    /// Where the picture is drawn inside this view (a photo is fitted, the live camera fills the view).
    var contentRect: (CGSize) -> CGRect = { CGRect(origin: .zero, size: $0) }
    /// Nil for live text: VisionKit gets the taps itself.
    var onTap: ((RecognizedLine) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let area = contentRect(proxy.size)
            ForEach(lines) { line in
                let rect = Self.rect(of: line, in: area)
                let isSelected = line.id == selectedID
                let shown = english(line)
                ZStack {
                    if let shown {
                        // The line's own height sets the size, so the English covers the original like a sticker.
                        // A fixed size is needed here: it follows the picture, not Dynamic Type.
                        Text(shown)
                            .font(.system(size: max(9, rect.height * 0.62)))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .padding(.horizontal, Theme.Spacing.xSmall)
                            .frame(width: rect.width, height: rect.height)
                            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Spacing.xSmall))
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    }
                    if isSelected {
                        RoundedRectangle(cornerRadius: Theme.Spacing.xSmall)
                            .fill(Theme.Colors.accent.opacity(shown == nil ? 0.15 : 0))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.Spacing.xSmall)
                                    .strokeBorder(Theme.Colors.accent, lineWidth: 3)
                            }
                    }
                }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .contentShape(Rectangle())
                .onTapGesture { onTap?(line) }
                .allowsHitTesting(onTap != nil)
                .accessibilityElement()
                .accessibilityLabel(shown ?? line.text)
                .accessibilityHint("Shows what it means")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    /// A line's box in view points, a little larger than the text.
    static func rect(of line: RecognizedLine, in area: CGRect) -> CGRect {
        CGRect(x: area.minX + line.box.minX * area.width,
               y: area.minY + (1 - line.box.maxY) * area.height,
               width: line.box.width * area.width, height: line.box.height * area.height)
            .insetBy(dx: -Theme.Spacing.xSmall, dy: -2)
    }

    /// The rectangle an aspect-fit image of `imageSize` takes inside `size`.
    static func fitted(_ imageSize: CGSize, in size: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: size) }
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2,
                      width: fitted.width, height: fitted.height)
    }
}
