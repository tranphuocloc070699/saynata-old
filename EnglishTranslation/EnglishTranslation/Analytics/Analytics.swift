//
//  Analytics.swift
//  EnglishTranslation
//
//  Usage events (PostHog) behind a small protocol, so tests use a fake (TASK-128.3). The event list and the
//  privacy rule are in `docs/analytics/events.md`.
//

import Foundation

/// Sends usage events somewhere: PostHog in the app (`PostHogSender`), a fake in tests.
protocol AnalyticsSending: AnyObject {
    func send(_ event: AnalyticsEvent)
    /// After sign-in: later events belong to this account. The user ID only, never the email.
    func identify(userID: Int)
    /// After sign-out: a new anonymous ID.
    func reset()
    /// The `signed_in` property sent with every event.
    func setSignedIn(_ isSignedIn: Bool)
    /// The "Share usage data" switch changed. Off also stops the SDK's own events (app opened).
    func setSharing(_ isOn: Bool)
}

/// The "Share usage data" switch in Settings (TASK-128.3). On by default (opt-out). Kept in the App Group, so the
/// Share and Translate extensions follow it too.
struct UsageSharingPreference {
    /// Same key as `@AppStorage` in the Settings screen.
    static let key = "shareUsageData"
    /// The App Group's defaults; the Settings switch uses the same store.
    static var sharedDefaults: UserDefaults { UserDefaults(suiteName: ResultCache.appGroupID) ?? .standard }

    var defaults: UserDefaults = Self.sharedDefaults

    var isOn: Bool {
        get { defaults.object(forKey: Self.key) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}

/// The one way the app sends usage events. Stores get it in `init` (default `.shared`); tests pass one with a fake
/// sender. Nothing is sent when the switch is off, in Debug builds (unless turned on), or without a key.
@MainActor
final class Analytics {
    /// The real one: PostHog when it is linked, turned on and has a key; otherwise it sends nothing.
    static let shared = Analytics(sender: PostHogSender.make(), preference: UsageSharingPreference())

    private let sender: (any AnalyticsSending)?
    private let preference: UsageSharingPreference

    init(sender: (any AnalyticsSending)?, preference: UsageSharingPreference = UsageSharingPreference()) {
        self.sender = sender
        self.preference = preference
    }

    /// Sends nothing. For previews.
    static func silent() -> Analytics {
        Analytics(sender: nil)
    }

    var isSharingOn: Bool { preference.isOn }

    func track(_ event: AnalyticsEvent) {
        guard isSharingOn, let sender else { return }
        sender.send(event)
    }

    /// Call after the Settings switch changed (it writes the value itself).
    func sharingChanged() {
        sender?.setSharing(isSharingOn)
    }

    /// The learner signed in on this device. `method` is nil when the session came from another process.
    func signedIn(userID: Int, method: SignInMethod?) {
        guard let sender else { return }
        sender.identify(userID: userID)
        sender.setSignedIn(true)
        if let method { track(.signedIn(method: method)) }
    }

    func signedOut() {
        guard let sender else { return }
        sender.reset()
        sender.setSignedIn(false)
    }
}

/// Starts crash reports and usage events. Every process calls it once, first: the app, the Mac app, the Share and
/// Translate extensions. Calling it again does nothing.
@MainActor
enum Telemetry {
    private static var isStarted = false

    static func start() {
        guard !isStarted else { return }
        isStarted = true
        CrashReporting.start()
        if let user = AccountStore.shared.user {
            Analytics.shared.signedIn(userID: user.id, method: nil)
        }
    }

    /// False in Debug builds, so the developer's own taps and the tests are not counted. To test sending from Xcode,
    /// add the launch argument `-SaynataSendTelemetryInDebug YES` (Edit Scheme > Run > Arguments).
    static var isEnabledInThisBuild: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "SaynataSendTelemetryInDebug")
        #else
        true
        #endif
    }

    /// The `platform` property: `ios` or `mac` (events.md).
    static var platform: String {
        #if os(macOS)
        "mac"
        #else
        "ios"
        #endif
    }

    /// The marketing version, for example "1.4.0".
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }
}
