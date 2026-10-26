import Foundation

/// Mirrors the backend's NoteResponse.
struct Note: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let body: String?
    let createdAt: Date
}

struct NewNote: Encodable, Sendable {
    let title: String
}
