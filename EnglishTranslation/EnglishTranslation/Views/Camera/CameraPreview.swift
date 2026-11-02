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

/// Outlines the picked lines over the camera or the photo. Boxes are 0...1 with the origin at the bottom left.
struct PickedLinesOverlay: View {
    let lines: [RecognizedLine]
    let picked: Set<Int>
    /// Where the picture is drawn inside this view (a photo is fitted, the live camera fills the view).
    var contentRect: (CGSize) -> CGRect = { CGRect(origin: .zero, size: $0) }
    /// Nil for live text: VisionKit handles taps itself.
    var onTap: ((RecognizedLine) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let area = contentRect(proxy.size)
            ForEach(lines) { line in
                let rect = CGRect(x: area.minX + line.box.minX * area.width,
                                  y: area.minY + (1 - line.box.maxY) * area.height,
                                  width: line.box.width * area.width, height: line.box.height * area.height)
                    .insetBy(dx: -Theme.Spacing.xSmall, dy: -Theme.Spacing.xSmall)
                let isPicked = picked.contains(line.id)
                RoundedRectangle(cornerRadius: Theme.Spacing.xSmall)
                    .fill(isPicked ? Theme.Colors.accent.opacity(0.18) : Color.clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Spacing.xSmall)
                            .strokeBorder(isPicked ? Theme.Colors.accent
                                              : Theme.Colors.surface.opacity(onTap == nil ? 0 : 0.8),
                                          style: StrokeStyle(lineWidth: isPicked ? 3 : 1.5, dash: isPicked ? [] : [4, 3]))
                    }
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap?(line) }
                    .allowsHitTesting(onTap != nil)
                    .accessibilityElement()
                    .accessibilityLabel(line.text)
                    .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
            }
        }
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
