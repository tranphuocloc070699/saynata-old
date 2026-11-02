//
//  CameraFeed.swift
//  EnglishTranslation
//
//  The back camera for object mode (TASK-121.4): a preview layer for the screen and a few frames a second as CGImage
//  for MobileCLIP. Text mode uses VisionKit's own camera instead (`LiveTextScanner`), never both at once.
//

import AVFoundation
import CoreImage
import Foundation

/// Whether the app may use the camera. Behind a protocol so the screen can be previewed without one.
nonisolated enum CameraAccess: Equatable, Sendable {
    case allowed, denied, notAsked

    static var current: CameraAccess {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .allowed
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    /// Shows the system question the first time ("Saynata would like to access the camera").
    static func ask() async -> CameraAccess {
        await AVCaptureDevice.requestAccess(for: .video) ? .allowed : .denied
    }
}

/// Owns the capture session. Frames are turned into images at most `framesPerSecond` times a second, off the main
/// thread; the store drops any that arrive while it is still busy.
nonisolated final class CameraFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    /// Called on a background queue with each kept frame (portrait: orientation `.right`).
    var onFrame: (@Sendable (CGImage) -> Void)?

    static let framesPerSecond: Double = 4

    private let queue = DispatchQueue(label: "saynata.camera.feed")
    private let context = CIContext()
    private var lastFrame = Date.distantPast
    private var isConfigured = false

    func start() {
        queue.async { [self] in
            if !isConfigured { configure() }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720 // plenty for a 256 px model, and light on the battery
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        isConfigured = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastFrame) >= 1 / Self.framesPerSecond,
              let onFrame, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = now
        let image = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return }
        onFrame(cgImage)
    }
}
