//
//  CameraScreen.swift
//  EnglishTranslation
//
//  The camera screen (F8, TASK-121.3 and 121.4, mockup approved 2026-11-02). Full screen over the home screen:
//  close, the text/objects switch and the photo button on top; the camera or the picked photo in the middle; the
//  bottom card for the mode. A result closes the screen and goes into the normal flow (explain first).
//

import AVFoundation
import ImageIO
import PhotosUI
import SwiftUI

enum CameraMode: Equatable {
    case text, objects
}

/// A photo from the library, ready for Vision and Core ML.
struct PickedPhoto {
    let uiImage: UIImage
    let cgImage: CGImage
    let orientation: CGImagePropertyOrientation

    init?(data: Data) {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return nil }
        uiImage = image
        self.cgImage = cgImage
        orientation = CGImagePropertyOrientation(image.imageOrientation)
    }
}

struct CameraScreen: View {
    let objectStore: CameraObjectStore
    /// The user picked text: explain it.
    let onText: (String) -> Void
    /// The user tapped a label: open its word card.
    let onLabel: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var mode: CameraMode = .text
    @State private var textStore = CameraTextStore()
    @State private var feed = CameraFeed()
    @State private var access = CameraAccess.current
    @State private var photo: PickedPhoto?
    @State private var photoItem: PhotosPickerItem?
    @State private var isPickerOpen = false

    var body: some View {
        ZStack {
            Theme.Colors.textPrimary.ignoresSafeArea()
            content.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Theme.Spacing.large)
                    .padding(.top, Theme.Spacing.small)
                Spacer()
                bottomCard
            }
        }
        .statusBarHidden()
        .photosPicker(isPresented: $isPickerOpen, selection: $photoItem, matching: .images)
        .task {
            if access == .notAsked { access = await CameraAccess.ask() }
            feed.onFrame = { [objectStore] image in
                Task { @MainActor in await objectStore.receive(image) }
            }
            updateFeed()
        }
        .onChange(of: mode) {
            textStore.clear()
            objectStore.reset()
            if let photo { Task { await analyse(photo) } }
            updateFeed()
        }
        .onChange(of: scenePhase) { updateFeed() }
        .onChange(of: photoItem) { Task { await loadPhoto() } }
        .onDisappear {
            feed.stop()
            objectStore.reset()
        }
    }

    // MARK: - Middle

    @ViewBuilder
    private var content: some View {
        if let photo {
            GeometryReader { proxy in
                Image(uiImage: photo.uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay {
                        if mode == .text {
                            PickedLinesOverlay(lines: textStore.lines, picked: textStore.picked,
                                               contentRect: { PickedLinesOverlay.fitted(photo.uiImage.size, in: $0) },
                                               onTap: { textStore.toggle($0) })
                        }
                    }
            }
        } else if access != .allowed {
            permissionMessage
        } else if mode == .text {
            if LiveTextScanner.isSupported {
                LiveTextScanner(store: textStore)
                    .overlay {
                        PickedLinesOverlay(lines: textStore.lines, picked: textStore.picked)
                            .allowsHitTesting(false) // VisionKit takes the taps
                    }
            }
        } else {
            CameraPreview(session: feed.session)
                .overlay {
                    // The middle square, so the user knows where to point.
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .strokeBorder(Theme.Colors.surface.opacity(0.7), lineWidth: 2)
                        .frame(width: 264, height: 264)
                        .accessibilityHidden(true)
                }
        }
    }

    private var permissionMessage: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Text("Allow the camera in Settings to use it here, or choose a photo.")
                .font(.body)
                .foregroundStyle(Theme.Colors.surface)
                .multilineTextAlignment(.center)
            IconButton(systemImage: "gearshape", label: "Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        }
        .padding(Theme.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            IconButton(systemImage: "xmark", label: "Close") { dismiss() }
            Spacer()
            modeSwitch
            Spacer()
            if photo == nil {
                IconButton(systemImage: "photo.on.rectangle", label: "Choose a photo") { isPickerOpen = true }
            } else {
                IconButton(systemImage: "camera", label: "Back to the camera") {
                    photo = nil
                    photoItem = nil
                    textStore.clear()
                    objectStore.reset()
                    updateFeed()
                }
            }
        }
    }

    /// Two icon segments in one capsule. A picker, so each segment says whether it is selected.
    private var modeSwitch: some View {
        HStack(spacing: 2) {
            modeSegment(.text, systemImage: "text.viewfinder", label: "Text")
            modeSegment(.objects, systemImage: "cube", label: "Objects")
        }
        .padding(3)
        .background(Theme.Colors.surface, in: Capsule())
        .overlay { Capsule().strokeBorder(Theme.Colors.hairline, lineWidth: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Camera mode")
    }

    private func modeSegment(_ value: CameraMode, systemImage: String, label: String) -> some View {
        let isSelected = mode == value
        return Button { mode = value } label: {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                .frame(width: 52, height: 38)
                .background(isSelected ? Theme.Colors.chipFill : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Bottom card

    private var bottomCard: some View {
        Group {
            switch mode {
            case .text:
                CameraTextPanel(store: textStore, liveTextMissing: photo == nil && !LiveTextScanner.isSupported) { text in
                    finish { onText(text) }
                }
            case .objects:
                CameraObjectPanel(store: objectStore) { label in
                    finish { onLabel(label) }
                }
            }
        }
        .padding(Theme.Spacing.large)
        .padding(.bottom, Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.card, topTrailingRadius: Theme.Radius.card)
                .fill(Theme.Colors.surface)
                .ignoresSafeArea(edges: .bottom))
        .animation(.default, value: mode)
    }

    // MARK: - Actions

    private func finish(_ handOff: @escaping () -> Void) {
        feed.stop()
        dismiss()
        handOff()
    }

    /// The object feed runs only in object mode, with no photo, while the app is in front.
    private func updateFeed() {
        if mode == .objects, photo == nil, access == .allowed, scenePhase == .active {
            feed.start()
        } else {
            feed.stop()
        }
    }

    private func loadPhoto() async {
        guard let photoItem, let data = try? await photoItem.loadTransferable(type: Data.self),
              let picked = PickedPhoto(data: data) else { return }
        photo = picked
        updateFeed()
        await analyse(picked)
    }

    private func analyse(_ photo: PickedPhoto) async {
        switch mode {
        case .text: await textStore.readPhoto(photo.cgImage, orientation: photo.orientation)
        case .objects: await objectStore.analysePhoto(photo.cgImage, orientation: photo.orientation)
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

#Preview("Object mode, unsure") {
    let labels = try! LabelIndex(labels: ["workstation", "desk", "table"], food: [false, false, false],
                                 dish: [false, false, false], dimension: 2, temperature: 1, vectors: [1, 0, 0, 1, 1, 1])
    CameraScreen(objectStore: CameraObjectStore(embedder: PreviewEmbedder(),
                                                makeCascade: { ObjectCascade(labels: labels, food: nil) },
                                                identifier: nil),
                 onText: { _ in }, onLabel: { _ in })
}

/// For previews: a fixed vector, no model.
private struct PreviewEmbedder: ImageEmbedding {
    func embedding(for image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [Float] { [0.7, 0.7] }
}
