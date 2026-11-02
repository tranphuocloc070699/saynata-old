//
//  LiveTextScanner.swift
//  EnglishTranslation
//
//  Live camera text for text mode (TASK-121.3): VisionKit's DataScannerViewController finds lines of text; each
//  update goes to `CameraTextStore` and a tap on a line picks it.
//

import SwiftUI
import VisionKit

struct LiveTextScanner: UIViewControllerRepresentable {
    let store: CameraTextStore

    /// False on devices without the Neural Engine features VisionKit needs, and in the simulator.
    static var isSupported: Bool { DataScannerViewController.isSupported }

    /// `CameraText.languages` that this phone's live text knows (TASK-121.6); English when none is listed.
    static var languages: [String] {
        let known = Set(DataScannerViewController.supportedTextRecognitionLanguages)
        let wanted = CameraText.languages.filter { known.contains($0) }
        return wanted.isEmpty ? ["en-US"] : wanted
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(languages: Self.languages)],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let store: CameraTextStore
        /// VisionKit ids are UUIDs; the store numbers lines, and a line keeps its number while it stays on screen.
        private var numbers: [RecognizedItem.ID: Int] = [:]
        private var nextNumber = 0

        init(store: CameraTextStore) { self.store = store }

        func dataScanner(_ scanner: DataScannerViewController, didAdd added: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            show(allItems, in: scanner)
        }

        func dataScanner(_ scanner: DataScannerViewController, didUpdate updated: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            show(allItems, in: scanner)
        }

        func dataScanner(_ scanner: DataScannerViewController, didRemove removed: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in removed { numbers[item.id] = nil }
            show(allItems, in: scanner)
        }

        func dataScanner(_ scanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard let number = numbers[item.id], let line = store.lines.first(where: { $0.id == number }) else { return }
            store.toggle(line)
        }

        /// Boxes are made 0...1 with the origin at the bottom left, like Vision's, so one overlay draws both.
        private func show(_ items: [RecognizedItem], in scanner: DataScannerViewController) {
            let size = scanner.view.bounds.size
            guard size.width > 0, size.height > 0 else { return }
            let lines = items.compactMap { item -> RecognizedLine? in
                guard case let .text(text) = item else { return nil }
                if numbers[item.id] == nil {
                    numbers[item.id] = nextNumber
                    nextNumber += 1
                }
                let corners = [text.bounds.topLeft, text.bounds.topRight, text.bounds.bottomLeft, text.bounds.bottomRight]
                let minX = corners.map(\.x).min() ?? 0, maxX = corners.map(\.x).max() ?? 0
                let minY = corners.map(\.y).min() ?? 0, maxY = corners.map(\.y).max() ?? 0
                let box = CGRect(x: minX / size.width, y: 1 - maxY / size.height,
                                 width: (maxX - minX) / size.width, height: (maxY - minY) / size.height)
                return RecognizedLine(id: numbers[item.id] ?? 0, text: text.transcript, box: box)
            }
            // Reading order, top to bottom (VisionKit gives them in no fixed order).
            store.showLive(lines.sorted { ($0.box.midY, -$0.box.minX) > ($1.box.midY, -$1.box.minX) })
        }
    }
}
