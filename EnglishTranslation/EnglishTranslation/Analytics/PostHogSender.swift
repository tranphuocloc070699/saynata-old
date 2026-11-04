//
//  PostHogSender.swift
//  EnglishTranslation
//
//  The real `AnalyticsSending`: PostHog Cloud US (doc-24, "Usage tracking"). Session Replay, screen views and
//  element capture stay off: they could record the text on screen.
//

import Foundation
#if canImport(PostHog)
import PostHog
#endif

final class PostHogSender: AnalyticsSending {
    /// The sender for this process, or nil (nothing is sent) in Debug, without the key, or without the SDK.
    static func make() -> PostHogSender? {
        #if canImport(PostHog)
        guard Telemetry.isEnabledInThisBuild, let key = AppConfig.postHogProjectKey() else { return nil }
        return PostHogSender(projectKey: key, host: AppConfig.postHogHost())
        #else
        return nil
        #endif
    }

    #if canImport(PostHog)
    private init(projectKey: String, host: String?) {
        let config = PostHogConfig(projectToken: projectKey, host: host ?? PostHogConfig.defaultHost)
        config.captureScreenViews = false
        // The app and its extensions share one anonymous ID and one queue.
        config.appGroupIdentifier = ResultCache.appGroupID
        config.optOut = !UsageSharingPreference().isOn
        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.register([
            "platform": Telemetry.platform,
            "app_version": Telemetry.appVersion,
            "signed_in": false,
        ])
    }

    func send(_ event: AnalyticsEvent) {
        PostHogSDK.shared.capture(event.name, properties: event.properties)
    }

    func identify(userID: Int) {
        PostHogSDK.shared.identify(String(userID))
    }

    func reset() {
        PostHogSDK.shared.reset()
        // `reset` clears the registered properties too.
        PostHogSDK.shared.register(["platform": Telemetry.platform, "app_version": Telemetry.appVersion])
    }

    func setSignedIn(_ isSignedIn: Bool) {
        PostHogSDK.shared.register(["signed_in": isSignedIn])
    }

    func setSharing(_ isOn: Bool) {
        if isOn { PostHogSDK.shared.optIn() } else { PostHogSDK.shared.optOut() }
    }
    #else
    func send(_ event: AnalyticsEvent) {}
    func identify(userID: Int) {}
    func reset() {}
    func setSignedIn(_ isSignedIn: Bool) {}
    func setSharing(_ isOn: Bool) {}
    #endif
}
