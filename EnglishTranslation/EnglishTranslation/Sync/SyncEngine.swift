//
//  SyncEngine.swift
//  EnglishTranslation
//

import Foundation

/// Where the answer of the server goes: the lists on this device (TASK-93.4).
@MainActor
protocol SyncMerging {
    /// Applies rows of `changes.history`. A newer local row wins over an older server row.
    func apply(history changes: [SyncItem]) async
    func apply(liked changes: [SyncItem]) async
    /// The History on this device, for the one-time upload at sign-in.
    func localHistory() async -> [SavedItem]
}

/// Sends the outbox and reads what changed on other devices. The screens never wait for it: a change is shown at once
/// and its op goes to the outbox; this class sends the outbox in the background.
///
/// - One `POST /api/sync` after `idleDelay` of quiet, at `batchSize` ops, or when the app goes to the background.
/// - A failed send keeps its ops and tries again later: 5 s, 10 s, 20 s ... up to 5 minutes.
/// - A guest never sends.
@MainActor
final class SyncEngine {
    /// The engine of the app. Its stores are the shared ones.
    static let shared: SyncEngine = SyncEngine(
        outbox: SyncOutbox.shared,
        makeAPI: { BackendClient(baseURL: try AppConfig.backendBaseURL(), cache: nil, auth: AccountStore.shared) },
        merger: StoreMerger(history: HistoryStore.shared, liked: LikedStore.shared),
        isSignedIn: { AccountStore.shared.isSignedIn },
        preferences: .shared)

    private let outbox: (any SyncOutboxing)?
    private let makeAPI: @MainActor () throws -> any SyncAPI
    private let merger: any SyncMerging
    private let isSignedIn: @MainActor () -> Bool
    private let preferences: SyncPreferences
    private let idleDelay: Duration
    private let batchSize: Int
    private let sleep: @Sendable (Duration) async throws -> Void

    /// The most ops one request carries (the server's limit).
    static let maxOpsPerRequest = 200

    private var timer: Task<Void, Never>?
    private var isSending = false
    /// How many sends in a row failed. 0 means all is well.
    private(set) var failureCount = 0

    /// - Parameters:
    ///   - outbox: Nil when the file cannot be opened: nothing is sent.
    ///   - sleep: Waits; tests pass a fast one.
    init(
        outbox: (any SyncOutboxing)?,
        makeAPI: @escaping @MainActor () throws -> any SyncAPI,
        merger: any SyncMerging,
        isSignedIn: @escaping @MainActor () -> Bool,
        preferences: SyncPreferences,
        idleDelay: Duration = .seconds(5),
        batchSize: Int = 20,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.outbox = outbox
        self.makeAPI = makeAPI
        self.merger = merger
        self.isSignedIn = isSignedIn
        self.preferences = preferences
        self.idleDelay = idleDelay
        self.batchSize = batchSize
        self.sleep = sleep
    }

    /// The wait before the next try after `failures` failures in a row.
    static func retryDelay(afterFailures failures: Int) -> Duration {
        .seconds(min(5 * (1 << min(max(failures, 1) - 1, 6)), 300))
    }

    // MARK: - Changes

    /// Call after an op was added to the outbox. Sends now at `batchSize` ops, otherwise after the quiet time.
    func noteChange() {
        guard isSignedIn(), outbox != nil else { return }
        Task {
            let waiting = await outbox?.count() ?? 0
            if waiting >= batchSize, failureCount == 0 {
                await sendNow()
            } else {
                schedule(after: failureCount == 0 ? idleDelay : Self.retryDelay(afterFailures: failureCount))
            }
        }
    }

    /// The app goes to the background: send what waits, before the system suspends the app.
    func appDidEnterBackground() async {
        timer?.cancel()
        await sendNow()
    }

    /// Launch and return to the foreground: send what waits and read what changed on other devices.
    func syncNow() async {
        await sendNow()
    }

    // MARK: - Account

    /// Signed in: put the History of this device into the outbox once, then sync.
    func signedIn() async {
        guard let outbox else { return }
        if preferences.isHistoryOn, await !outbox.hasUploadedHistory() {
            let ops = await merger.localHistory().map { SyncOp(type: .historyAdd, item: $0, at: $0.date) }
            await outbox.append(ops)
            await outbox.setUploadedHistory(true)
        }
        await sendNow()
    }

    /// Signed out: forget the queue and the cursor. The next account starts from the beginning.
    func signedOut() async {
        timer?.cancel()
        failureCount = 0
        await outbox?.reset()
    }

    /// The learner turned "Sync history" back on: the History of this device goes up again.
    func historySyncTurnedOn() async {
        await outbox?.setUploadedHistory(false)
        await signedIn()
    }

    // MARK: - Sending

    private func schedule(after delay: Duration) {
        timer?.cancel()
        timer = Task { [sleep] in
            do { try await sleep(delay) } catch { return }
            guard !Task.isCancelled else { return }
            await sendNow()
        }
    }

    private func sendNow() async {
        guard let outbox, isSignedIn(), !isSending else { return }
        isSending = true
        defer { isSending = false }
        timer?.cancel()
        do {
            let api = try makeAPI()
            var more = true
            while more {
                let queued = await outbox.pending(limit: Self.maxOpsPerRequest)
                let response = try await api.sync(since: await outbox.cursor(), ops: queued.map(\.op))
                await outbox.remove(ids: queued.map(\.id))
                await outbox.setCursor(response.cursor)
                await merger.apply(history: response.changes.history)
                await merger.apply(liked: response.changes.liked)
                failureCount = 0
                more = queued.count == Self.maxOpsPerRequest
            }
        } catch BackendError.signInRequired {
            // The session ended. The ops stay; the sign-in screen is the way forward.
        } catch {
            failureCount += 1
            schedule(after: Self.retryDelay(afterFailures: failureCount))
        }
    }
}

/// Puts the answer of the server into the real stores. History goes to the plain `HistoryStore`, not to the one that
/// writes ops, so a server row does not come back as a new op.
@MainActor
struct StoreMerger: SyncMerging {
    let history: (any HistoryStoring)?
    let liked: LikedStore

    func apply(history changes: [SyncItem]) async {
        guard let history, !changes.isEmpty else { return }
        let local = Dictionary(await history.items().map { ($0.id, $0.date) }, uniquingKeysWith: { first, _ in first })
        for change in changes {
            let item = change.savedItem
            let localDate = local[item.id]
            if change.deleted {
                if let localDate, localDate <= change.at { await history.remove(id: item.id) }
            } else if localDate == nil || localDate! < change.at {
                await history.record(item)
            }
        }
    }

    func apply(liked changes: [SyncItem]) async {
        liked.merge(changes)
    }

    func localHistory() async -> [SavedItem] {
        await history?.items() ?? []
    }
}
