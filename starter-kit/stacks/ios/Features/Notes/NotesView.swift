import SwiftUI

struct NotesView: View {
    @Environment(NotesStore.self) private var store
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New note", text: $newTitle)
                            .onSubmit(add)
                        Button(action: add) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .accessibilityLabel("Add note")
                        .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                if let message = store.errorMessage {
                    Text(message).foregroundStyle(.red)
                }
                ForEach(store.notes) { note in
                    Text(note.title)
                }
            }
            .overlay { if store.isLoading && store.notes.isEmpty { ProgressView() } }
            .navigationTitle("Notes")
            .task { await store.load() }
            .refreshable { await store.load() }
        }
    }

    private func add() {
        let title = newTitle
        newTitle = ""
        Task { await store.add(title: title) }
    }
}

#Preview {
    NotesView()
        .environment(NotesStore(api: APIClient(baseURL: URL(string: "http://localhost:8080")!, transport: URLSessionTransport())))
}
