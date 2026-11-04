//
//  CrashReporting.swift
//  EnglishTranslation
//
//  Crashes and errors go to Sentry project `saynata-ios` (the Mac app too; doc-24, "Error reporting").
//  No user content: no network breadcrumbs (their URLs hold the looked-up word), no request data, no screenshots.
//  The "Share usage data" switch does not stop crash reports; they carry no user content.
//

import Foundation
#if canImport(Sentry)
import Sentry
#endif

enum CrashReporting {
    /// Called by `Telemetry.start()`. Does nothing in Debug (unless turned on) or without the DSN.
    static func start() {
        #if canImport(Sentry)
        guard Telemetry.isEnabledInThisBuild, let dsn = AppConfig.sentryDSN() else { return }
        let platform = Telemetry.platform
        SentrySDK.start { options in
            options.dsn = dsn
            #if DEBUG
            options.environment = "debug"
            #else
            options.environment = "production"
            #endif
            options.sendDefaultPii = false
            options.enableNetworkBreadcrumbs = false
            options.enableCaptureFailedRequests = false
            options.enableAutoPerformanceTracing = false
            options.beforeSend = { @Sendable event in
                CrashReporting.scrub(event)
            }
        }
        SentrySDK.configureScope { scope in
            scope.setTag(value: platform, key: "platform")
        }
        #endif
    }

    #if canImport(Sentry)
    /// Removes anything that could hold user content before an event leaves the device.
    nonisolated static func scrub(_ event: Event) -> Event {
        event.request = nil
        event.user = nil
        event.breadcrumbs = event.breadcrumbs?.filter { $0.category != "http" }
        return event
    }
    #endif
}
