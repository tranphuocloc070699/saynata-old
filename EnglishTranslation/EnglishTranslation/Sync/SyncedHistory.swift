//
//  SyncedHistory.swift
//  EnglishTranslation
//

import Foundation

/// The History of the app, plus an op in the outbox for each change (TASK-93.4). The list on the device changes at
/// once, as before; the op is sent later by `SyncEngine`. Ops are written only for a signed-in user whose
/// "Sync history" switch is on. The Share and Translate extensions use this too.
struct SyncedHistory: HistoryStoring {
    let base: any HistoryStoring
    let outbox: any SyncOutboxing
    /// True when changes should be queued: signed in, and the switch is on.
    let isEnabled: @Sendable () async -> Bool
    /// Called after an op was queued, so the engine can start its timer.
    let didQueue: @Sendable () async -> Void

    /// The History of the app and the extensions. Nil when the file cannot be opened, and inside unit tests.
    static let shared: (any HistoryStoring)? = {
        guard let base = HistoryStore.shared, let outbox = SyncOutbox.shared else { return HistoryStore.shared }
        return SyncedHistory(
            base: base, outbox: outbox,
            isEnabled: { await MainActor.run { AccountStore.shared.isSignedIn && SyncPreferences.shared.isHistoryOn } },
            didQueue: { await MainActor.run { SyncEngine.shared.noteChange() } })
    }()

    func record(_ item: SavedItem) async {
        await base.record(item)
        await queue(SyncOp(type: .historyAdd, item: item, at: item.date))
    }

    func items() async -> [SavedItem] { await base.items() }

    func remove(id: String) async {
        await base.remove(id: id)
        await queue(SyncOp(type: .historyRemove, itemID: id, at: .now))
    }

    func removeAll() async {
        await base.removeAll()
        await queue(SyncOp(type: .historyClear, at: .now))
    }

    private func queue(_ op: SyncOp) async {
        guard await isEnabled() else { return }
        await outbox.append(op)
        await didQueue()
    }
}
