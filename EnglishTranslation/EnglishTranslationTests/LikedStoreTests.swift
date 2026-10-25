//
//  LikedStoreTests.swift
//  EnglishTranslationTests
//
//  TASK-93.2 and 93.4: the liked list (guest, like, unlike, offline copy, ops in the outbox), the old `/api/liked`
//  calls, and History in TranslationStore.
//

import Foundation
import Testing
@testable import EnglishTranslation

private final class MemoryCopy: LikedCopyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [SavedItem]
    init(_ items: [SavedItem] = []) { stored = items }
    func load() -> [SavedItem] { lock.withLock { stored } }
    func save(_ items: [SavedItem]) { lock.withLock { stored = items } }
}

private let apple = SavedItem(kind: .word, text: "apple", preview: "a fruit", chip: "noun · A1")
private let sentence = SavedItem(kind: .sentence, text: "The fog was thick.", preview: "It was hard to see.")

@MainActor
struct LikedStoreTests {
    private func makeStore(
        outbox: SyncOutbox, copy: MemoryCopy = MemoryCopy(), signedIn: Bool = true, queued: Counter? = nil
    ) -> LikedStore {
        LikedStore(copy: copy, outbox: outbox, isSignedIn: { signedIn }, didQueue: { queued?.value += 1 })
    }

    @MainActor final class Counter { var value = 0 }

    @Test func likingShowsAtOnceAndQueuesAnOp() async throws {
        let outbox = try SyncOutbox(fileURL: nil)
        let queued = Counter()
        let store = makeStore(outbox: outbox, queued: queued)
        await store.toggle(apple)
        #expect(store.isLiked(apple))
        let ops = await outbox.pending(limit: 10).map(\.op)
        #expect(ops.map(\.type) == [.likedAdd])
        #expect(ops.first?.text == "apple")
        #expect(ops.first?.preview == "a fruit")
        #expect(queued.value == 1)
    }

    @Test func tappingAgainUnlikesAndQueuesARemove() async throws {
        let outbox = try SyncOutbox(fileURL: nil)
        let store = makeStore(outbox: outbox)
        await store.toggle(apple)
        await store.toggle(apple)
        #expect(!store.isLiked(apple))
        #expect(await outbox.pending(limit: 10).map(\.op.type) == [.likedAdd, .likedRemove])
    }

    @Test func aGuestGetsTheSignInSheetAndNothingIsQueued() async throws {
        let outbox = try SyncOutbox(fileURL: nil)
        let store = makeStore(outbox: outbox, signedIn: false)
        await store.toggle(apple)
        #expect(store.signInRequested)
        #expect(store.pending == apple)
        #expect(store.items.isEmpty)
        #expect(await outbox.count() == 0)
    }

    @Test func afterSignInThePendingLikeIsAddedAndQueued() async throws {
        let outbox = try SyncOutbox(fileURL: nil)
        let account = Counter()
        let store = LikedStore(copy: MemoryCopy(), outbox: outbox, isSignedIn: { account.value == 1 })
        await store.toggle(apple)
        #expect(store.items.isEmpty)
        account.value = 1
        await store.signedIn()
        #expect(store.isLiked(apple))
        #expect(store.pending == nil)
        #expect(await outbox.pending(limit: 10).map(\.op.type) == [.likedAdd])
    }

    @Test func closingTheSheetDropsThePendingLike() async throws {
        let store = makeStore(outbox: try SyncOutbox(fileURL: nil), signedIn: false)
        await store.toggle(apple)
        store.cancelPending()
        await store.signedIn()
        #expect(store.items.isEmpty)
    }

    @Test func theCopyOnThePhoneShowsAtOnceAndOffline() async throws {
        let copy = MemoryCopy([apple])
        let store = makeStore(outbox: try SyncOutbox(fileURL: nil), copy: copy)
        #expect(store.isLiked(apple))
        await store.toggle(sentence)
        #expect(copy.load().map(\.id) == [sentence.id, apple.id])
    }

    @Test func swipeToUnlike() async throws {
        let outbox = try SyncOutbox(fileURL: nil)
        let store = makeStore(outbox: outbox, copy: MemoryCopy([apple, sentence]))
        await store.unlike(id: apple.id)
        #expect(store.items.map(\.id) == [sentence.id])
        #expect(await outbox.pending(limit: 10).map(\.op.type) == [.likedRemove])
    }

    @Test func signingOutClearsTheCopy() throws {
        let copy = MemoryCopy([apple])
        let store = makeStore(outbox: try SyncOutbox(fileURL: nil), copy: copy)
        store.clear()
        #expect(store.items.isEmpty)
        #expect(copy.load().isEmpty)
    }

    @Test func mergeAddsRemovesAndKeepsTheLabel() throws {
        let day = Date(timeIntervalSince1970: 1_000_000)
        let local = SavedItem(kind: .word, text: "apple", preview: "old", chip: "noun · A1", date: day)
        let gone = SavedItem(kind: .word, text: "pear", preview: "x", date: day)
        let store = makeStore(outbox: try SyncOutbox(fileURL: nil), copy: MemoryCopy([local, gone]))
        store.merge([
            SyncItem(kind: .word, text: "apple", preview: "new", at: day.addingTimeInterval(60)),
            SyncItem(kind: .word, text: "pear", at: day.addingTimeInterval(60), deleted: true),
            SyncItem(kind: .sentence, text: "Hi.", preview: "A greeting.", at: day.addingTimeInterval(120)),
        ])
        #expect(store.items.map(\.text) == ["Hi.", "apple"])
        #expect(store.items.last?.preview == "new")
        #expect(store.items.last?.chip == "noun · A1")
    }

    @Test func aNewerLocalChangeWinsOverAnOlderServerRow() throws {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let local = SavedItem(kind: .word, text: "apple", preview: "mine", date: now)
        let store = makeStore(outbox: try SyncOutbox(fileURL: nil), copy: MemoryCopy([local]))
        store.merge([
            SyncItem(kind: .word, text: "apple", at: now.addingTimeInterval(-60), deleted: true),
            SyncItem(kind: .word, text: "apple", preview: "theirs", at: now.addingTimeInterval(-30)),
        ])
        #expect(store.items.first?.preview == "mine")
    }
}

/// The three calls of `/api/liked` through `BackendClient`, with a fake server.
struct LikedAPITests {
    private let server = ScriptedServer()

    private func client(token: String? = "A1") -> BackendClient {
        let secrets = FakeSecretStore()
        if token != nil { try? secrets.setSecret(savedSessionJSON(access: "A1", refresh: "R1"), forKey: "session") }
        return BackendClient(
            baseURL: server.baseURL, session: server.session,
            auth: AccountStore(secrets: secrets, client: AuthClient(baseURL: server.baseURL, session: server.session)))
    }

    @Test func listReadsItemsWithAndWithoutFractionalSeconds() async throws {
        server.handler = { _ in .json("""
            {"items":[
              {"kind":"word","text":"apple","preview":"a fruit","createdAt":"2026-10-19T10:00:00.123Z"},
              {"kind":"sentence","text":"Hi there.","preview":"A greeting.","createdAt":"2026-10-18T09:30:00Z"}]}
            """) }

        let items = try await client().likedItems()

        #expect(items.map(\.text) == ["apple", "Hi there."])
        #expect(items[1].kind == .sentence)
        #expect(server.requests.first?.authorization == "Bearer A1")
        #expect(server.requests.first?.path == "/api/liked")
    }

    @Test func likeSendsAPutWithTheKindTextAndPreview() async throws {
        server.handler = { _ in .json(#"{"kind":"word","text":"apple","preview":"a fruit","createdAt":"2026-10-19T10:00:00Z"}"#) }

        try await client().like(SavedItem(kind: .word, text: "apple", preview: "a fruit"))

        let request = try #require(server.requests.first)
        #expect(request.method == "PUT")
        #expect(request.json["kind"] as? String == "word")
        #expect(request.json["text"] as? String == "apple")
        #expect(request.json["preview"] as? String == "a fruit")
    }

    @Test func unlikeSendsADeleteAndAcceptsNoContent() async throws {
        server.handler = { _ in .empty(204) }

        try await client().unlike(kind: .sentence, text: "Hi there & bye.")

        let request = try #require(server.requests.first)
        #expect(request.method == "DELETE")
        #expect(request.query.contains("kind=sentence"))
        #expect(request.query.contains("%26"))
    }

    @Test func aGuestGetsSignInRequired() async {
        server.handler = { _ in .problem(401, code: "sign_in_required") }

        await #expect(throws: BackendError.signInRequired) {
            _ = try await client(token: nil).likedItems()
        }
    }
}

/// History is written where the final result is set (TASK-93.2).
@MainActor
struct TranslationStoreHistoryTests {
    private struct FakeTranslator: Translating {
        var result: Result<Explanation, Error>
        func explain(_ text: String, translatingTo language: TargetLanguage) async throws -> Explanation { try result.get() }
        func explainStreaming(
            _ text: String, translatingTo language: TargetLanguage,
            onMeaning: @escaping @MainActor @Sendable (String) -> Void
        ) async throws -> Explanation { try result.get() }
    }

    private struct FakeWords: WordLooking {
        var entry: WordEntry?
        var phrase: WordEntry?
        func lookUp(_ word: String) async throws -> WordEntry {
            guard let entry else { throw URLError(.notConnectedToInternet) }
            return entry
        }
        func phraseEntry(for phrase: String) async -> WordEntry? { self.phrase }
    }

    private let sense = Sense(pos: "noun", cefr: "A1", simpleDefinition: "a fruit", vietnamese: "quả táo", examples: [])

    private func makeStore(history: MemoryHistory, words: FakeWords = FakeWords(),
                           sentence: Result<Explanation, Error> = .failure(URLError(.badServerResponse))) -> TranslationStore {
        TranslationStore(
            makeTranslator: { FakeTranslator(result: sentence) },
            makeWordLookup: { words },
            history: history)
    }

    @Test func aWordResultIsRecorded() async {
        let history = MemoryHistory()
        let store = makeStore(history: history, words: FakeWords(entry: WordEntry(word: "apple", ipa: nil, senses: [sense])))
        store.inputText = "apple"
        await store.translate()
        #expect(await history.items().map(\.text) == ["apple"])
    }

    @Test func aPhraseHitIsRecorded() async {
        let history = MemoryHistory()
        let phrase = WordEntry(word: "give up", ipa: nil, senses: [sense])
        let store = makeStore(history: history, words: FakeWords(phrase: phrase))
        store.inputText = "give up"
        await store.translate()
        #expect(await history.items().map(\.text) == ["give up"])
    }

    @Test func aSentenceResultIsRecorded() async {
        let history = MemoryHistory()
        let explanation = Explanation(meaning: "A greeting.", words: [], translation: "Xin chào")
        let store = makeStore(history: history, sentence: .success(explanation))
        store.inputText = "Hello there my friend."
        await store.translate()
        let items = await history.items()
        #expect(items.map(\.text) == ["Hello there my friend."])
        #expect(items.first?.preview == "A greeting.")
    }

    @Test func aFailureIsNotRecorded() async {
        let history = MemoryHistory()
        let store = makeStore(history: history)
        store.inputText = "apple"
        await store.translate()
        store.inputText = "Hello there my friend."
        await store.translate()
        #expect(await history.items().isEmpty)
    }
}
