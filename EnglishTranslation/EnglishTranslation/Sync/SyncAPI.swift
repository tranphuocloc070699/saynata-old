//
//  SyncAPI.swift
//  EnglishTranslation
//

import Foundation

/// The server side of sync: `POST /api/sync` and `GET`/`PUT /api/me/settings` (TASK-93.3).
/// `BackendClient` is the real one; tests use a fake. All calls throw `BackendError.signInRequired` for a guest.
protocol SyncAPI: Sendable {
    func sync(since: Int, ops: [SyncOp]) async throws -> SyncResponse
    func accountSettings() async throws -> AccountSettings
    func updateAccountSettings(_ settings: AccountSettings) async throws
}

private struct SyncRequest: Encodable {
    let since: Int
    let ops: [SyncOp]
}

extension BackendClient: SyncAPI {
    func sync(since: Int, ops: [SyncOp]) async throws -> SyncResponse {
        var request = URLRequest(url: baseURL.appending(path: "api/sync"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SyncRequest(since: since, ops: ops))
        return try JSONDecoder().decode(SyncResponse.self, from: try await sendChecked(request))
    }

    func accountSettings() async throws -> AccountSettings {
        let data = try await sendChecked(URLRequest(url: baseURL.appending(path: "api/me/settings")))
        return try JSONDecoder().decode(AccountSettings.self, from: data)
    }

    func updateAccountSettings(_ settings: AccountSettings) async throws {
        var request = URLRequest(url: baseURL.appending(path: "api/me/settings"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(settings)
        _ = try await sendChecked(request)
    }
}
