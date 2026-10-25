//
//  LikedStore.swift
//  EnglishTranslation
//

import Foundation
import Observation

/// The server side of Liked: `GET`, `PUT` and `DELETE /api/liked` (TASK-93.1). `BackendClient` is the real one;
/// tests use a fake. All three throw `BackendError.signInRequired` for a guest.
protocol LikedAPI: Sendable {
    func likedItems() async throws -> [SavedItem]
    func like(_ item: SavedItem) async throws
    func unlike(kind: SavedItem.Kind, text: String) async throws
}

/// The copy of the liked list on the phone, so the stars and the Liked list show at once and offline.
protocol LikedCopyStoring: Sendable {
    func load() -> [SavedItem]
    func save(_ items: [SavedItem])
}

/// The copy as a JSON file in the App Group folder (the extensions read the same file).
struct LikedCopyFile: LikedCopyStoring {
    let fileURL: URL

    static let shared = LikedCopyFile(fileURL: ResultCache.cacheFolder().appending(path: "liked-copy.json"))

    func load() -> [SavedItem] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([SavedItem].self, from: data)) ?? []
    }

    func save(_ items: [SavedItem]) {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

/// The liked words and sentences of the signed-in user (TASK-93.2, local-first since TASK-93.4). Views read `items` and
/// `isLiked`; the star calls `toggle`. The change shows at once, is saved on the phone and goes to the outbox; `SyncEngine`
/// sends it later. A network error never undoes a like.
@Observable
@MainActor
final class LikedStore {
    /// The store of the app and the extensions. One list in memory, so every screen shows the same stars.
    static let shared: LikedStore = LikedStore(
        copy: LikedCopyFile.shared,
        outbox: SyncOutbox.shared,
        isSignedIn: { AccountStore.shared.isSignedIn },
        didQueue: { SyncEngine.shared.noteChange() })

    /// Newest first.
    private(set) var items: [SavedItem]
    /// True when a guest tapped the star. The main screen opens the sign-in sheet and sets it back to false.
    var signInRequested = false

    /// The like that waits for a sign-in. It is added by `signedIn()`.
    private(set) var pending: SavedItem?

    @ObservationIgnored private let copy: any LikedCopyStoring
    @ObservationIgnored private let outbox: (any SyncOutboxing)?
    @ObservationIgnored private let isSignedIn: @MainActor () -> Bool
    @ObservationIgnored private let didQueue: @MainActor () -> Void

    /// - Parameters:
    ///   - outbox: Where the ops go. Nil: the list works on the phone only.
    ///   - isSignedIn: True when there is a signed-in account. A guest gets the sign-in sheet and queues nothing.
    ///   - didQueue: Called after an op was queued, so the engine can start its timer.
    init(
        copy: any LikedCopyStoring,
        outbox: (any SyncOutboxing)?,
        isSignedIn: @escaping @MainActor () -> Bool,
        didQueue: @escaping @MainActor () -> Void = {}
    ) {
        self.copy = copy
        self.outbox = outbox
        self.isSignedIn = isSignedIn
        self.didQueue = didQueue
        items = copy.load()
    }

    /// The real store (shared by the whole app).
    static func live() -> LikedStore { shared }

    func isLiked(_ item: SavedItem) -> Bool {
        items.contains { $0.id == item.id }
    }

    // MARK: - Star

    /// Likes the item, or unlikes it when it is liked. A guest gets the sign-in sheet instead, and the like
    /// is added after sign-in.
    func toggle(_ item: SavedItem) async {
        guard isSignedIn() else {
            pending = item
            signInRequested = true
            return
        }
        if isLiked(item) {
            await unlike(id: item.id)
        } else {
            await like(item)
        }
    }

    private func like(_ item: SavedItem) async {
        let liked = SavedItem(kind: item.kind, text: item.text, preview: item.preview, chip: item.chip, date: .now)
        setItems([liked] + items.filter { $0.id != item.id })
        await queue(SyncOp(type: .likedAdd, item: liked, at: liked.date))
    }

    /// Unlikes by item id. Also used by the swipe in the Liked list.
    func unlike(id: String) async {
        guard let item = items.first(where: { $0.id == id }) else { return }
        setItems(items.filter { $0.id != id })
        await queue(SyncOp(type: .likedRemove, item: item, at: .now))
    }

    private func queue(_ op: SyncOp) async {
        guard let outbox else { return }
        await outbox.append(op)
        didQueue()
    }

    // MARK: - Sign-in and sign-out

    /// The user signed in: add the like that was waiting. The engine syncs the rest.
    func signedIn() async {
        let waiting = pending
        pending = nil
        if let waiting, !isLiked(waiting) {
            await like(waiting)
        }
    }

    /// The sign-in sheet was closed without signing in.
    func cancelPending() {
        pending = nil
    }

    /// Reads the file again: an extension may have changed it while the app was away.
    func reloadFromCopy() {
        items = copy.load()
    }

    /// Applies rows of `changes.liked`. A local change newer than the server row wins. The label of a word (`chip`) is
    /// not on the server, so it is kept from the copy on the phone.
    func merge(_ changes: [SyncItem]) {
        guard !changes.isEmpty else { return }
        var merged = items
        for change in changes {
            let incoming = change.savedItem
            let index = merged.firstIndex { $0.id == incoming.id }
            if change.deleted {
                if let index, merged[index].date <= change.at { merged.remove(at: index) }
            } else if let index {
                if merged[index].date < change.at {
                    merged[index] = SavedItem(
                        kind: incoming.kind, text: incoming.text, preview: incoming.preview,
                        chip: merged[index].chip, date: incoming.date)
                }
            } else {
                merged.append(incoming)
            }
        }
        setItems(merged.sorted { $0.date > $1.date })
    }

    /// Signed out: the liked list belongs to the account, so it goes from this phone.
    func clear() {
        pending = nil
        setItems([])
    }

    private func setItems(_ new: [SavedItem]) {
        items = new
        copy.save(new)
    }
}
