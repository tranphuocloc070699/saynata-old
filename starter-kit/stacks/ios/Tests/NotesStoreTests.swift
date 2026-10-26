import Foundation
import Testing
@testable import App

/// Returns canned responses, so tests never touch the network.
struct FakeTransport: HTTPTransport {
    let status: Int
    let json: String

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(json.utf8), response)
    }
}

@MainActor
struct NotesStoreTests {
    private func makeStore(status: Int, json: String) -> NotesStore {
        NotesStore(api: APIClient(baseURL: URL(string: "http://test")!, transport: FakeTransport(status: status, json: json)))
    }

    @Test func loadShowsNotesFromTheAPI() async {
        let store = makeStore(status: 200, json: """
            [{"id":1,"title":"First","body":null,"createdAt":"2026-01-01T10:00:00.123456Z"}]
            """)

        await store.load()

        #expect(store.notes.map(\.title) == ["First"])
        #expect(store.errorMessage == nil)
    }

    @Test func apiErrorShowsItsMessage() async {
        let store = makeStore(status: 404, json: #"{"code":"note_not_found","detail":"No note"}"#)

        await store.load()

        #expect(store.notes.isEmpty)
        #expect(store.errorMessage == "No note")
    }

    @Test func blankTitleIsNotSent() async {
        let store = makeStore(status: 500, json: "{}")

        await store.add(title: "   ")

        #expect(store.errorMessage == nil)
    }
}
