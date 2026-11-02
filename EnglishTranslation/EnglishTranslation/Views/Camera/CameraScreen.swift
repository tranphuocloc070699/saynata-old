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
import Translation

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
    /// The language line under a tapped line's explanation (TASK-121.7).
    var targetLanguage: TargetLanguage = .vietnamese

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var mode: CameraMode = .text
    @State private var textStore = CameraTextStore(explainer: try? TranslatorFactory.makeTranslator())
    /// Apple Translation for the English drawn over other-language lines (TASK-121.7).
    @State private var englishConfig: TranslationSession.Configuration?
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
        .onChange(of: textStore.englishRequest) { _, request in
            guard let request else { return }
            let source = Locale.Language(identifier: request.language)
            if englishConfig?.source == source {
                englishConfig?.invalidate() // same language, new lines: run the task again
            } else {
                englishConfig = .init(source: source, target: Locale.Language(identifier: "en"))
            }
        }
        .translationTask(englishConfig) { session in
            await textStore.makeEnglish(with: SessionEnglish(session: session))
        }
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
                            linesLayer(contentRect: { TextLinesOverlay.fitted(photo.uiImage.size, in: $0) },
                                       tappable: true)
                        }
                    }
            }
        } else if access != .allowed {
            permissionMessage
        } else if mode == .text {
            if LiveTextScanner.isSupported {
                LiveTextScanner(store: textStore, isPaused: textStore.selectedLine != nil, onTap: { select($0) })
                    .overlay {
                        linesLayer(contentRect: { CGRect(origin: .zero, size: $0) }, tappable: false)
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

    /// The English over the lines, the outline of the tapped line, and its explanation bubble (mockup 6A).
    /// Live text: VisionKit gets the line taps, so only the bubble layer takes touches.
    private func linesLayer(contentRect: @escaping (CGSize) -> CGRect, tappable: Bool) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                TextLinesOverlay(lines: textStore.lines, english: { textStore.overlayText(for: $0) },
                                 selectedID: textStore.selectedLine?.id, contentRect: contentRect,
                                 onTap: tappable ? { select($0) } : nil)
                    .allowsHitTesting(tappable && textStore.selectedLine == nil)
                if let line = textStore.selectedLine {
                    // Tap outside the bubble: close it.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { textStore.closeExplanation() }
                        .accessibilityHidden(true)
                    callout(for: line, area: contentRect(proxy.size), size: proxy.size)
                }
            }
        }
    }

    private func callout(for line: RecognizedLine, area: CGRect, size: CGSize) -> some View {
        let lineRect = TextLinesOverlay.rect(of: line, in: area)
        let place = CalloutPlacement.place(lineRect: lineRect, in: size)
        return LineExplanationCallout(explanation: textStore.explanation, language: targetLanguage) {
            finish { onText(line.text) }
        }
        .padding(.horizontal, Theme.Spacing.large)
        .frame(width: size.width)
        .fixedSize(horizontal: false, vertical: true)
        .alignmentGuide(.top) { dimensions in place.above ? -(place.y - dimensions.height) : -place.y }
        .transition(.opacity)
    }

    private func select(_ line: RecognizedLine) {
        Task { await textStore.select(line, language: targetLanguage) }
    }

    private var permissionMessage: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Text("Allow the camera in Settings to use it here, or choose a photo.")
                .font(.body)
                .foregroundStyle(Theme.Colors.surface)
                .multilineTextAlignment(.center)
            IconButton(systemImage: "gearshape", label: "Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
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
            if textStore.selectedLine == nil { modeSwitch }
            Spacer()
            if mode == .text, textStore.hasEnglishOverlay {
                IconButton(systemImage: textStore.showsOriginal ? "eye.slash" : "eye",
                           label: textStore.showsOriginal ? "Show English" : "Show the original text") {
                    textStore.showsOriginal.toggle()
                }
            }
            if textStore.selectedLine != nil {
                EmptyView()
            } else if photo == nil {
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
                CameraTextPanel(store: textStore, liveTextMissing: photo == nil && !LiveTextScanner.isSupported,
                                hasEnglish: textStore.hasEnglishOverlay) { text in
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

/// Apple Translation behind `EnglishMaking`: one request per line, answers matched by their number.
struct SessionEnglish: EnglishMaking {
    let session: TranslationSession

    func english(for texts: [String]) async throws -> [String] {
        let requests = texts.enumerated().map {
            TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset))
        }
        var english = Array(repeating: "", count: texts.count)
        for response in try await session.translations(from: requests) {
            if let id = response.clientIdentifier, let index = Int(id), english.indices.contains(index) {
                english[index] = response.targetText
            }
        }
        return english
    }
}

/// For previews: a fixed vector, no model.
private struct PreviewEmbedder: ImageEmbedding {
    func embedding(for image: CGImage, orientation: CGImagePropertyOrientation) async throws -> [Float] { [0.7, 0.7] }
}
