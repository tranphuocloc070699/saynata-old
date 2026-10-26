import Sentry
import SwiftUI

@main
struct MainApp: App {
    @State private var notesStore: NotesStore

    init() {
        let config = AppConfig.fromBundle()
        if !config.sentryDSN.isEmpty {
            SentrySDK.start { options in
                options.dsn = config.sentryDSN
                options.environment = config.environment
                options.sendDefaultPii = false
                options.tracesSampleRate = 0.1
            }
        }
        let api = APIClient(baseURL: config.apiBaseURL, transport: URLSessionTransport())
        _notesStore = State(initialValue: NotesStore(api: api))
    }

    var body: some Scene {
        WindowGroup {
            NotesView()
                .environment(notesStore)
        }
    }
}
