//
//  SyncModels.swift
//  EnglishTranslation
//

import Foundation

/// Time as the sync API writes it: ISO-8601, with or without fractions of a second.
enum SyncDates {
    static func string(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    static func date(_ text: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) { return date }
        return try? Date.ISO8601FormatStyle().parse(text)
    }
}

/// One change made on this device, waiting in the outbox to go to `POST /api/sync` (TASK-93.4).
/// The same JSON is saved in the outbox file and sent to the server.
struct SyncOp: Codable, Equatable, Sendable {
    enum OpType: String, Codable, Sendable {
        case historyAdd = "history_add"
        case historyRemove = "history_remove"
        case historyClear = "history_clear"
        case likedAdd = "liked_add"
        case likedRemove = "liked_remove"
    }

    let type: OpType
    /// Nil for `history_clear`.
    let kind: SavedItem.Kind?
    let text: String?
    let preview: String?
    let chip: String?
    /// Device time of the change. The server keeps the newest `at` (last write wins).
    let at: Date

    private enum CodingKeys: String, CodingKey { case type, kind, text, preview, chip, at }

    init(type: OpType, item: SavedItem? = nil, at: Date) {
        self.type = type
        kind = item?.kind
        text = item?.text
        preview = type == .historyAdd || type == .likedAdd ? item?.preview : nil
        chip = type == .historyAdd ? item?.chip : nil
        self.at = at
    }

    /// An op that names an item only by its id (`kind:text`), like a History swipe does.
    init(type: OpType, itemID: String, at: Date) {
        self.type = type
        let parts = itemID.split(separator: ":", maxSplits: 1).map(String.init)
        kind = parts.first.flatMap(SavedItem.Kind.init(rawValue:))
        text = parts.count > 1 ? parts[1] : nil
        preview = nil
        chip = nil
        self.at = at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(OpType.self, forKey: .type)
        kind = try container.decodeIfPresent(SavedItem.Kind.self, forKey: .kind)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        preview = try container.decodeIfPresent(String.self, forKey: .preview)
        chip = try container.decodeIfPresent(String.self, forKey: .chip)
        let at = try container.decode(String.self, forKey: .at)
        guard let date = SyncDates.date(at) else {
            throw DecodingError.dataCorruptedError(forKey: .at, in: container, debugDescription: "Not a date: \(at)")
        }
        self.at = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(preview, forKey: .preview)
        try container.encodeIfPresent(chip, forKey: .chip)
        try container.encode(SyncDates.string(at), forKey: .at)
    }
}

/// One row of `changes.history` or `changes.liked`. `deleted` is a tombstone: remove it on this device.
struct SyncItem: Decodable, Equatable, Sendable {
    let kind: SavedItem.Kind
    let text: String
    let preview: String
    let chip: String?
    let at: Date
    let deleted: Bool

    private enum CodingKeys: String, CodingKey { case kind, text, preview, chip, at, deleted }

    init(kind: SavedItem.Kind, text: String, preview: String = "", chip: String? = nil, at: Date, deleted: Bool = false) {
        self.kind = kind
        self.text = text
        self.preview = preview
        self.chip = chip
        self.at = at
        self.deleted = deleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(SavedItem.Kind.self, forKey: .kind)
        text = try container.decode(String.self, forKey: .text)
        preview = try container.decodeIfPresent(String.self, forKey: .preview) ?? ""
        chip = try container.decodeIfPresent(String.self, forKey: .chip)
        let at = try container.decode(String.self, forKey: .at)
        guard let date = SyncDates.date(at) else {
            throw DecodingError.dataCorruptedError(forKey: .at, in: container, debugDescription: "Not a date: \(at)")
        }
        self.at = date
        deleted = try container.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
    }

    var savedItem: SavedItem { SavedItem(kind: kind, text: text, preview: preview, chip: chip, date: at) }
}

/// The answer of `POST /api/sync`.
struct SyncResponse: Decodable, Equatable, Sendable {
    struct Changes: Decodable, Equatable, Sendable {
        let history: [SyncItem]
        let liked: [SyncItem]

        init(history: [SyncItem] = [], liked: [SyncItem] = []) {
            self.history = history
            self.liked = liked
        }
    }

    let changes: Changes
    let cursor: Int

    init(changes: Changes = .init(), cursor: Int) {
        self.changes = changes
        self.cursor = cursor
    }
}

/// `GET /api/me/settings`. `showTranslation` is `collapsed`, `alwaysOpen` or `remember`.
struct AccountSettings: Codable, Equatable, Sendable {
    var targetLanguage: String
    var showTranslation: String
    var syncHistory: Bool
}
