//
//  SyncTests.swift
//  EnglishTranslationTests
//
//  TASK-93.4: the outbox, the sync engine (batching, retry, merge, upload at sign-in), History ops and account settings.
//

import Foundation
import Testing
@testable import EnglishTranslation

// MARK: - Fakes

/// A sync API in memory. Remembers every request; answers from `responses` (the last one repeats), or throws `failure`.
final class FakeSyncAPI: SyncAPI, @unchecked Sendable {
    struct Call: Equatable { let since: Int; let ops: [SyncOp] }

    private let lock = NSLock()
    private var _calls: [Call] = []
    private var _failure: Error?
    private var _responses: [SyncResponse]
    private var _settings: AccountSettings
    private var _updates: [AccountSettings] = []

    init(responses: [SyncResponse] = [SyncResponse(cursor: 1)],
         settings: AccountSettings = AccountSettings(targetLanguage: "vi", showTranslation: "remember", syncHistory: true)) {
        _responses = responses
        _settings = settings
    }

    var calls: [Call] { lock.withLock { _calls } }
    var updates: [AccountSettings] { lock.withLock { _updates } }
    var failure: Error? {
        get { lock.withLock { _failure } }
        set { lock.withLock { _failure = newValue } }
    }

    func sync(since: Int, ops: [SyncOp]) async throws -> SyncResponse {
        try lock.withLock {
            _calls.append(Call(since: since, ops: ops))
            if let _failure { throw _failure }
            return _responses.count > 1 ? _responses.removeFirst() : _responses[0]
        }
    }

    func accountSettings() async throws -> AccountSettings {
        try lock.withLock {
            if let _failure { throw _failure }
            return _settings
        }
    }

    func updateAccountSettings(_ settings: AccountSettings) async throws {
        try lock.withLock {
            if let _failure { throw _failure }
            _updates.append(settings)
            _settings = settings
        }
    }
}

/// A sleep the test controls: every wait stays open until `fireAll()`.
final class TestSleeper: @unchecked Sendable {
    private let lock = NSLock()
    private var _durations: [Duration] = []
    private var waiters: [CheckedContinuation<Void, Error>] = []

    var durations: [Duration] { lock.withLock { _durations } }

    func sleep(_ duration: Duration) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                _durations.append(duration)
                waiters.append(continuation)
            }
        }
    }

    func fireAll() {
        let open = lock.withLock { () -> [CheckedContinuation<Void, Error>] in
            defer { waiters = [] }
            return waiters
        }
        open.forEach { $0.resume() }
    }
}

/// Waits (up to about 2 s) until `condition` is true.
func waitUntil(_ condition: () async -> Bool) async {
    for _ in 0..<400 {
        if await condition() { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
}

@MainActor
final class RecordingMerger: SyncMerging {
    var history: [[SyncItem]] = []
    var liked: [[SyncItem]] = []
    var local: [SavedItem] = []
    func apply(history changes: [SyncItem]) async { history.append(changes) }
    func apply(liked changes: [SyncItem]) async { liked.append(changes) }
    func localHistory() async -> [SavedItem] { local }
}

@MainActor
final class Flag {
    var isOn: Bool
    init(_ isOn: Bool = true) { self.isOn = isOn }
}

private func op(_ text: String, at seconds: TimeInterval = 100) -> SyncOp {
    SyncOp(type: .historyAdd, item: SavedItem(kind: .word, text: text, preview: "p"), at: Date(timeIntervalSince1970: seconds))
}

private func emptyPreferences(historyOn: Bool = true) -> SyncPreferences {
    let preferences = SyncPreferences(defaults: TargetLanguagePreference.makeEmptyDefaults())
    preferences.isHistoryOn = historyOn
    return preferences
}

// MARK: - Models and outbox

struct SyncOutboxTests {
    @Test func opsComeBackOldestFirstAndCanBeRemoved() async throws {
        let outbox = try SyncOutbox(fileURL: nil)
        await outbox.append([op("a"), op("b"), op("c")])
        let queued = await outbox.pending(limit: 2)
        #expect(queued.map(\.op.text) == ["a", "b"])
        await outbox.remove(ids: queued.map(\.id))
        #expect(await outbox.pending(limit: 10).map(\.op.text) == ["c"])
        #expect(await outbox.count() == 1)
    }

    @Test func theFileKeepsOpsAndTheCursorForTheNextProcess() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Sync Outbox \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "sync-outbox.sqlite")

        let first = try SyncOutbox(fileURL: url)
        await first.append(op("a"))
        await first.setCursor(42)
        await first.setUploadedHistory(true)

        let second = try SyncOutbox(fileURL: url)
        #expect(await second.pending(limit: 10).map(\.op.text) == ["a"])
        #expect(await second.cursor() == 42)
        #expect(await second.hasUploadedHistory())
        await second.reset()
        #expect(await second.count() == 0)
        #expect(await second.cursor() == 0)
        #expect(await !second.hasUploadedHistory())
    }

    @Test func anOpIsSentAsTheApiExpectsIt() throws {
        let item = SavedItem(kind: .word, text: "Apple", preview: "a fruit", chip: "noun · A1")
        let add = SyncOp(type: .historyAdd, item: item, at: Date(timeIntervalSince1970: 1_761_379_200.5))
        let json = try #require(String(data: JSONEncoder().encode(add), encoding: .utf8))
        #expect(json.contains("\"type\":\"history_add\""))
        #expect(json.contains("\"kind\":\"word\""))
        #expect(json.contains("\"at\":\"2025-10-25T08:00:00.500Z\""))
        #expect(try JSONDecoder().decode(SyncOp.self, from: Data(json.utf8)) == add)

        let clear = try JSONEncoder().encode(SyncOp(type: .historyClear, at: .now))
        let clearJSON = try #require(String(data: clear, encoding: .utf8))
        #expect(!clearJSON.contains("\"text\""))
    }

    @Test func aRemoveByIdSplitsKindAndText() {
        let remove = SyncOp(type: .historyRemove, itemID: "sentence:Hi: there.", at: .now)
        #expect(remove.kind == .sentence)
        #expect(remove.text == "Hi: there.")
    }

    @Test func aResponseReadsDatesAndTombstones() throws {
        let json = """
            {"changes":{"history":[{"kind":"word","text":"apple","preview":"a fruit","chip":"noun · A1","at":"2026-10-25T08:00:00.123Z","deleted":false}],
            "liked":[{"kind":"sentence","text":"Hi.","preview":"","at":"2026-10-25T08:00:00Z","deleted":true}]},"cursor":57}
            """
        let response = try JSONDecoder().decode(SyncResponse.self, from: Data(json.utf8))
        #expect(response.cursor == 57)
        #expect(response.changes.history.first?.chip == "noun · A1")
        #expect(response.changes.liked.first?.deleted == true)
    }
}

// MARK: - Engine

@MainActor
struct SyncEngineTests {
    private struct Rig {
        let engine: SyncEngine
        let outbox: SyncOutbox
        let api: FakeSyncAPI
        let sleeper: TestSleeper
        let merger: RecordingMerger
        let account: Flag
    }

    private func makeRig(
        api: FakeSyncAPI = FakeSyncAPI(), signedIn: Bool = true, historyOn: Bool = true, batchSize: Int = 20
    ) throws -> Rig {
        let outbox = try SyncOutbox(fileURL: nil)
        let sleeper = TestSleeper()
        let merger = RecordingMerger()
        let account = Flag(signedIn)
        let engine = SyncEngine(
            outbox: outbox, makeAPI: { api }, merger: merger, isSignedIn: { account.isOn },
            preferences: emptyPreferences(historyOn: historyOn), batchSize: batchSize,
            sleep: { try await sleeper.sleep($0) })
        return Rig(engine: engine, outbox: outbox, api: api, sleeper: sleeper, merger: merger, account: account)
    }

    @Test func changesWaitFiveSecondsOfQuietThenGoInOneRequest() async throws {
        let rig = try makeRig()
        for name in ["a", "b", "c"] {
            await rig.outbox.append(op(name))
            rig.engine.noteChange()
        }
        await waitUntil { rig.sleeper.durations.count == 3 }
        #expect(rig.sleeper.durations.allSatisfy { $0 == .seconds(5) })
        #expect(rig.api.calls.isEmpty)

        rig.sleeper.fireAll()
        await waitUntil { !rig.api.calls.isEmpty }
        try await Task.sleep(for: .milliseconds(50))
        #expect(rig.api.calls.count == 1)
        #expect(rig.api.calls[0].ops.map(\.text) == ["a", "b", "c"])
        #expect(rig.api.calls[0].since == 0)
        #expect(await rig.outbox.count() == 0)
        #expect(await rig.outbox.cursor() == 1)
    }

    @Test func twentyOpsAreSentAtOnce() async throws {
        let rig = try makeRig()
        await rig.outbox.append((0..<20).map { op("w\($0)") })
        rig.engine.noteChange()
        await waitUntil { !rig.api.calls.isEmpty }
        #expect(rig.api.calls.first?.ops.count == 20)
    }

    @Test func leavingTheAppSendsAtOnce() async throws {
        let rig = try makeRig()
        await rig.outbox.append([op("a"), op("b")])
        await rig.engine.appDidEnterBackground()
        #expect(rig.api.calls.count == 1)
        #expect(await rig.outbox.count() == 0)
    }

    @Test func aGuestNeverSends() async throws {
        let rig = try makeRig(signedIn: false)
        await rig.outbox.append(op("a"))
        rig.engine.noteChange()
        await rig.engine.appDidEnterBackground()
        await rig.engine.syncNow()
        #expect(rig.api.calls.isEmpty)
        #expect(rig.sleeper.durations.isEmpty)
        #expect(await rig.outbox.count() == 1)
    }

    @Test func aFailedSendKeepsTheOpsAndRetriesWithGrowingWaits() async throws {
        let api = FakeSyncAPI()
        api.failure = URLError(.notConnectedToInternet)
        let rig = try makeRig(api: api)
        await rig.outbox.append([op("a"), op("b")])

        await rig.engine.appDidEnterBackground()
        #expect(rig.engine.failureCount == 1)
        #expect(await rig.outbox.count() == 2)
        await waitUntil { rig.sleeper.durations.count == 1 }
        #expect(rig.sleeper.durations.last == .seconds(5))

        rig.sleeper.fireAll()
        await waitUntil { api.calls.count == 2 && rig.sleeper.durations.count == 2 }
        #expect(rig.sleeper.durations.last == .seconds(10))
        #expect(await rig.outbox.count() == 2)

        api.failure = nil
        rig.sleeper.fireAll()
        await waitUntil { rig.engine.failureCount == 0 }
        #expect(api.calls.count == 3)
        #expect(api.calls[2].ops.map(\.text) == ["a", "b"])
        #expect(await rig.outbox.count() == 0)
    }

    @Test func retryWaitsDoubleUpToFiveMinutes() {
        #expect([1, 2, 3, 4, 5, 6, 7, 20].map { SyncEngine.retryDelay(afterFailures: $0) }
            == [5, 10, 20, 40, 80, 160, 300, 300].map { Duration.seconds($0) })
    }

    @Test func anEndedSessionKeepsTheOpsAndDoesNotRetry() async throws {
        let api = FakeSyncAPI()
        api.failure = BackendError.signInRequired
        let rig = try makeRig(api: api)
        await rig.outbox.append(op("a"))
        await rig.engine.appDidEnterBackground()
        #expect(await rig.outbox.count() == 1)
        #expect(rig.sleeper.durations.isEmpty)
        #expect(rig.engine.failureCount == 0)
    }

    @Test func theAnswerIsMergedAndTheCursorIsUsedNextTime() async throws {
        let change = SyncItem(kind: .word, text: "apple", preview: "a fruit", at: Date(timeIntervalSince1970: 500))
        let like = SyncItem(kind: .sentence, text: "Hi.", at: Date(timeIntervalSince1970: 600), deleted: true)
        let api = FakeSyncAPI(responses: [
            SyncResponse(changes: .init(history: [change], liked: [like]), cursor: 7),
            SyncResponse(cursor: 9),
        ])
        let rig = try makeRig(api: api)
        await rig.engine.syncNow()
        #expect(rig.merger.history == [[change]])
        #expect(rig.merger.liked == [[like]])
        await rig.engine.syncNow()
        #expect(api.calls.map(\.since) == [0, 7])
        #expect(await rig.outbox.cursor() == 9)
    }

    @Test func moreThan200OpsGoInSeveralRequests() async throws {
        let rig = try makeRig()
        await rig.outbox.append((0..<250).map { op("w\($0)") })
        await rig.engine.syncNow()
        #expect(rig.api.calls.map(\.ops.count) == [200, 50])
        #expect(await rig.outbox.count() == 0)
    }

    @Test func signingInUploadsTheLocalHistoryOnce() async throws {
        let rig = try makeRig()
        rig.merger.local = [
            SavedItem(kind: .word, text: "apple", preview: "a fruit", date: Date(timeIntervalSince1970: 100)),
            SavedItem(kind: .sentence, text: "Hi.", preview: "A greeting.", date: Date(timeIntervalSince1970: 200)),
        ]
        await rig.engine.signedIn()
        #expect(rig.api.calls.count == 1)
        #expect(rig.api.calls[0].ops.map(\.type) == [.historyAdd, .historyAdd])
        #expect(rig.api.calls[0].ops.map(\.at) == [Date(timeIntervalSince1970: 100), Date(timeIntervalSince1970: 200)])

        await rig.engine.signedIn()
        #expect(rig.api.calls.count == 2)
        #expect(rig.api.calls[1].ops.isEmpty)
    }

    @Test func signingOutForgetsEverythingSoTheNextAccountUploadsAgain() async throws {
        let rig = try makeRig()
        rig.merger.local = [SavedItem(kind: .word, text: "apple", preview: "")]
        await rig.engine.signedIn()
        await rig.outbox.append(op("left over"))
        await rig.engine.signedOut()
        #expect(await rig.outbox.count() == 0)
        #expect(await rig.outbox.cursor() == 0)

        await rig.engine.signedIn()
        #expect(rig.api.calls.last?.since == 0)
        #expect(rig.api.calls.last?.ops.count == 1)
    }

    @Test func historyIsNotUploadedWhileTheSwitchIsOff() async throws {
        let rig = try makeRig(historyOn: false)
        rig.merger.local = [SavedItem(kind: .word, text: "apple", preview: "")]
        await rig.engine.signedIn()
        #expect(rig.api.calls.first?.ops.isEmpty == true)
    }
}

// MARK: - History ops and merging

struct SyncedHistoryTests {
    private func make(enabled: Bool = true) throws -> (SyncedHistory, MemoryHistory, SyncOutbox) {
        let base = MemoryHistory()
        let outbox = try SyncOutbox(fileURL: nil)
        return (SyncedHistory(base: base, outbox: outbox, isEnabled: { enabled }, didQueue: {}), base, outbox)
    }

    @Test func eachChangeShowsAtOnceAndQueuesAnOp() async throws {
        let (history, base, outbox) = try make()
        let item = SavedItem(kind: .word, text: "Apple", preview: "a fruit", chip: "noun · A1")
        await history.record(item)
        await history.remove(id: item.id)
        await history.removeAll()
        #expect(await base.items().isEmpty)
        let ops = await outbox.pending(limit: 10).map(\.op)
        #expect(ops.map(\.type) == [.historyAdd, .historyRemove, .historyClear])
        #expect(ops[0].chip == "noun · A1")
        #expect(ops[1].kind == .word && ops[1].text == "apple")
    }

    @Test func nothingIsQueuedForAGuestOrWithTheSwitchOff() async throws {
        let (history, base, outbox) = try make(enabled: false)
        await history.record(SavedItem(kind: .word, text: "apple", preview: ""))
        #expect(await base.items().count == 1)
        #expect(await outbox.count() == 0)
    }
}

@MainActor
struct StoreMergerTests {
    private let day = Date(timeIntervalSince1970: 1_000_000)

    @Test func serverRowsAreAddedAndTombstonesRemoveOlderLocalRows() async throws {
        let old = SavedItem(kind: .word, text: "old", preview: "", date: day)
        let history = MemoryHistory([old])
        let liked = LikedStore(copy: LikedCopyMemory(), outbox: nil, isSignedIn: { true })
        let merger = StoreMerger(history: history, liked: liked)
        await merger.apply(history: [
            SyncItem(kind: .word, text: "new", preview: "fresh", at: day.addingTimeInterval(10)),
            SyncItem(kind: .word, text: "old", at: day.addingTimeInterval(5), deleted: true),
        ])
        #expect(await history.items().map(\.text) == ["new"])
    }

    @Test func aNewerLocalRowSurvivesAnOlderTombstone() async throws {
        let mine = SavedItem(kind: .word, text: "mine", preview: "", date: day)
        let history = MemoryHistory([mine])
        let merger = StoreMerger(history: history, liked: LikedStore(copy: LikedCopyMemory(), outbox: nil, isSignedIn: { true }))
        await merger.apply(history: [SyncItem(kind: .word, text: "mine", at: day.addingTimeInterval(-10), deleted: true)])
        #expect(await history.items().count == 1)
    }
}

private final class LikedCopyMemory: LikedCopyStoring, @unchecked Sendable {
    func load() -> [SavedItem] { [] }
    func save(_ items: [SavedItem]) {}
}

// MARK: - Account settings

@MainActor
struct SettingsSyncTests {
    private struct Rig {
        let sync: SettingsSync
        let api: FakeSyncAPI
        let language: TargetLanguagePreference
        let rows: TranslationRowPreference
        let preferences: SyncPreferences
        let sleeper: TestSleeper
    }

    private func makeRig(api: FakeSyncAPI = FakeSyncAPI(), signedIn: Bool = true) -> Rig {
        let language = TargetLanguagePreference(defaults: TargetLanguagePreference.makeEmptyDefaults())
        let rows = TranslationRowPreference(defaults: TargetLanguagePreference.makeEmptyDefaults())
        let preferences = emptyPreferences()
        let sleeper = TestSleeper()
        let sync = SettingsSync(
            makeAPI: { api }, isSignedIn: { signedIn }, language: language, rows: rows, sync: preferences,
            sleep: { try await sleeper.sleep($0) })
        return Rig(sync: sync, api: api, language: language, rows: rows, preferences: preferences, sleeper: sleeper)
    }

    @Test func aChangeIsSentInTheBackgroundWithAllThreeValues() async {
        let rig = makeRig()
        rig.language.language = .korean
        rig.rows.mode = .alwaysOpen
        rig.sync.settingsChanged()
        #expect(rig.preferences.settingsDirty)
        await waitUntil { rig.sleeper.durations.count == 1 }
        rig.sleeper.fireAll()
        await waitUntil { !rig.api.updates.isEmpty }
        #expect(rig.api.updates == [AccountSettings(targetLanguage: "ko", showTranslation: "alwaysOpen", syncHistory: true)])
        await waitUntil { !rig.preferences.settingsDirty }
        #expect(!rig.preferences.settingsDirty)
    }

    @Test func launchReadsTheAccountSettingsIntoTheDevice() async {
        let api = FakeSyncAPI(settings: AccountSettings(targetLanguage: "ko", showTranslation: "collapsed", syncHistory: false))
        let rig = makeRig(api: api)
        let changed = await rig.sync.syncNow()
        #expect(changed == .korean)
        #expect(rig.language.language == .korean)
        #expect(rig.rows.mode == .collapsed)
        #expect(!rig.preferences.isHistoryOn)
    }

    @Test func aChangeThatDidNotArriveIsSentInsteadOfBeingOverwritten() async {
        let api = FakeSyncAPI(settings: AccountSettings(targetLanguage: "vi", showTranslation: "remember", syncHistory: true))
        let rig = makeRig(api: api)
        rig.language.language = .korean
        rig.preferences.settingsDirty = true
        _ = await rig.sync.syncNow()
        #expect(api.updates.map(\.targetLanguage) == ["ko"])
        #expect(rig.language.language == .korean)
        #expect(!rig.preferences.settingsDirty)
    }

    @Test func aFailedSendKeepsTheMark() async {
        let api = FakeSyncAPI()
        api.failure = URLError(.notConnectedToInternet)
        let rig = makeRig(api: api)
        rig.preferences.settingsDirty = true
        _ = await rig.sync.syncNow()
        #expect(rig.preferences.settingsDirty)
    }

    @Test func aGuestSendsAndReadsNothing() async {
        let rig = makeRig(signedIn: false)
        rig.sync.settingsChanged()
        #expect(await rig.sync.syncNow() == nil)
        #expect(rig.sleeper.durations.isEmpty)
        #expect(rig.api.updates.isEmpty)
    }

    @Test func syncHistoryIsOnByDefault() {
        #expect(emptyPreferences().isHistoryOn)
        #expect(SyncPreferences(defaults: TargetLanguagePreference.makeEmptyDefaults()).isHistoryOn)
    }
}
