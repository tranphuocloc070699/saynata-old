import Foundation
import Observation

/// State for the Notes screen. Views read it; only the store changes it.
@MainActor
@Observable
final class NotesStore {
    private(set) var notes: [Note] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            notes = try await api.get("api/v1/notes")
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Something went wrong"
        }
    }

    func add(title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            let note: Note = try await api.post("api/v1/notes", body: NewNote(title: trimmed))
            notes.insert(note, at: 0)
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.message
        } catch {
            errorMessage = "Something went wrong"
        }
    }
}
