//
//  SyncOutbox.swift
//  EnglishTranslation
//

import Foundation
import SQLite3

/// An op with its row number in the outbox, so the sender can delete exactly what it sent.
struct QueuedOp: Equatable, Sendable {
    let id: Int64
    let op: SyncOp
}

/// The changes that wait to be sent, plus the sync cursor. `SyncOutbox` is the real one; tests use it in memory.
protocol SyncOutboxing: Sendable {
    func append(_ ops: [SyncOp]) async
    /// Oldest first.
    func pending(limit: Int) async -> [QueuedOp]
    func remove(ids: [Int64]) async
    func count() async -> Int
    /// Drops every op and forgets the cursor and the upload flag (sign-out).
    func reset() async
    /// `since` for the next `POST /api/sync`. 0 on a new account.
    func cursor() async -> Int
    func setCursor(_ cursor: Int) async
    /// True once the local History went up for this sign-in.
    func hasUploadedHistory() async -> Bool
    func setUploadedHistory(_ value: Bool) async
}

extension SyncOutboxing {
    func append(_ op: SyncOp) async { await append([op]) }
}

/// The outbox in a small SQLite file in the App Group folder, next to `HistoryStore`, so the Share and Translate
/// extensions add ops to the same queue as the app (TASK-93.4).
actor SyncOutbox: SyncOutboxing {
    /// Nil if the file cannot be opened, and inside unit tests (like `HistoryStore.shared`).
    static let shared: SyncOutbox? = {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return nil }
        let folder = ResultCache.cacheFolder()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try? SyncOutbox(fileURL: folder.appending(path: "sync-outbox.sqlite"))
    }()

    private let database: OpaquePointer

    /// Opens (or creates) the file. Pass `nil` for an outbox that lives only in memory (tests).
    init(fileURL: URL?) throws {
        var handle: OpaquePointer?
        let path = fileURL?.path(percentEncoded: false) ?? ":memory:"
        guard sqlite3_open(path, &handle) == SQLITE_OK, let handle else {
            sqlite3_close(handle)
            throw ResultCacheError.cannotOpen(path)
        }
        sqlite3_busy_timeout(handle, 2000)
        let schema = """
            CREATE TABLE IF NOT EXISTS outbox (id INTEGER PRIMARY KEY AUTOINCREMENT, op TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS meta (name TEXT PRIMARY KEY, value TEXT NOT NULL);
            """
        guard sqlite3_exec(handle, schema, nil, nil, nil) == SQLITE_OK else {
            sqlite3_close(handle)
            throw ResultCacheError.cannotOpen(path)
        }
        database = handle
    }

    deinit {
        sqlite3_close(database)
    }

    func append(_ ops: [SyncOp]) {
        for op in ops {
            guard let data = try? JSONEncoder().encode(op), let json = String(data: data, encoding: .utf8) else { continue }
            run("INSERT INTO outbox (op) VALUES (?)", binding: json)
        }
    }

    func pending(limit: Int) -> [QueuedOp] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT id, op FROM outbox ORDER BY id LIMIT ?", -1, &statement, nil) == SQLITE_OK
        else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, Int32(limit))
        var result: [QueuedOp] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = sqlite3_column_int64(statement, 0)
            guard let text = sqlite3_column_text(statement, 1),
                  let op = try? JSONDecoder().decode(SyncOp.self, from: Data(String(cString: text).utf8))
            else { continue }
            result.append(QueuedOp(id: id, op: op))
        }
        return result
    }

    func remove(ids: [Int64]) {
        for id in ids { run("DELETE FROM outbox WHERE id = ?", binding: String(id)) }
    }

    func count() -> Int {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM outbox", -1, &statement, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(statement) }
        return sqlite3_step(statement) == SQLITE_ROW ? Int(sqlite3_column_int(statement, 0)) : 0
    }

    func reset() {
        run("DELETE FROM outbox")
        run("DELETE FROM meta")
    }

    func cursor() -> Int { meta("cursor").flatMap { Int($0) } ?? 0 }
    func setCursor(_ cursor: Int) { setMeta("cursor", String(cursor)) }
    func hasUploadedHistory() -> Bool { meta("historyUploaded") == "1" }
    func setUploadedHistory(_ value: Bool) { setMeta("historyUploaded", value ? "1" : "0") }

    private func meta(_ name: String) -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT value FROM meta WHERE name = ?", -1, &statement, nil) == SQLITE_OK
        else { return nil }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, name, -1, Self.copyBytes)
        guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else { return nil }
        return String(cString: text)
    }

    private func setMeta(_ name: String, _ value: String) {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "INSERT OR REPLACE INTO meta (name, value) VALUES (?, ?)", -1, &statement, nil)
            == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, name, -1, Self.copyBytes)
        sqlite3_bind_text(statement, 2, value, -1, Self.copyBytes)
        _ = sqlite3_step(statement)
    }

    private func run(_ sql: String, binding value: String? = nil) {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }
        if let value { sqlite3_bind_text(statement, 1, value, -1, Self.copyBytes) }
        _ = sqlite3_step(statement)
    }

    private static let copyBytes = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
