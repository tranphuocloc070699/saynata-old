//
//  VisionIdentifying.swift
//  EnglishTranslation
//
//  "Ask AI" in object mode (TASK-121.4): one photo to POST /api/vision/identify (TASK-121.1), which names the thing
//  with a vision model through ClaudeGate (signed-in only, rate limit, daily budget). The server keeps only the answer.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// What the backend saw in the photo.
struct VisionAnswer: Decodable, Equatable, Sendable {
    enum Kind: String, Decodable, Sendable {
        case object, dish, text
    }

    let label: String
    let kind: Kind
    let confidence: Double
}

protocol VisionIdentifying: Sendable {
    /// Sends one JPEG (already made small) and returns the label. Throws `BackendError` (sign-in, limits) or `URLError`.
    func identify(jpeg: Data) async throws -> VisionAnswer
}

extension BackendClient: VisionIdentifying {
    func identify(jpeg: Data) async throws -> VisionAnswer {
        let boundary = "saynata-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appending(path: "api/vision/identify"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = MultipartBody.image(jpeg, field: "image", boundary: boundary)
        let data = try await sendChecked(request)
        return try JSONDecoder().decode(VisionAnswer.self, from: data)
    }
}

enum MultipartBody {
    static func image(_ jpeg: Data, field: String, boundary: String) -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(field)\"; filename=\"photo.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpeg)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }
}

/// Makes the photo small before it leaves the phone: the long side at most 768 px, JPEG quality 0.7.
/// That is well under the server's 2 MB limit and plenty for naming one thing.
enum SmallJPEG {
    static let maxSide = 768
    static let quality = 0.7

    static func make(from image: CGImage, orientation: CGImagePropertyOrientation = .up) -> Data? {
        let scaled = scaledDown(image) ?? image
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyOrientation: orientation.rawValue,
        ]
        CGImageDestinationAddImage(destination, scaled, options as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// The size after scaling, keeping the aspect ratio. Never scales up.
    static func targetSize(width: Int, height: Int) -> (width: Int, height: Int) {
        let longest = max(width, height)
        guard longest > maxSide else { return (width, height) }
        let factor = Double(maxSide) / Double(longest)
        return (max(1, Int((Double(width) * factor).rounded())), max(1, Int((Double(height) * factor).rounded())))
    }

    private static func scaledDown(_ image: CGImage) -> CGImage? {
        let size = targetSize(width: image.width, height: image.height)
        guard size.width != image.width || size.height != image.height else { return nil }
        guard let context = CGContext(data: nil, width: size.width, height: size.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return context.makeImage()
    }
}
