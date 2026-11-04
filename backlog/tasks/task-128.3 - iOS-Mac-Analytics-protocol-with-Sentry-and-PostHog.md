---
id: TASK-128.3
title: 'iOS/Mac: Analytics protocol with Sentry and PostHog'
status: In Progress
assignee:
  - '@claude'
created_date: 2026-11-04 10:35
updated_date: '2026-11-04T12:01:00Z'
labels:
  - analytics
dependencies:
  - TASK-128.1
references:
  - https://developer.apple.com/app-store/user-privacy-and-data-use/
parent_task_id: TASK-128
ordinal: 162000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The app (and the Mac app and extensions, which compile the app folder) needs crash reports and the shared events. Follows the project rule: system APIs behind a small protocol with a fake for tests.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 An Analytics protocol is injected like the other stores; tests use a fake and check that key flows send the right event
- [ ] #2 Events from the shared list fire from the app, Share extension, App Intents and the Mac panel with the right source
- [ ] #3 Crashes and errors reach Sentry for iOS and Mac; nothing is sent in Debug unless turned on
- [ ] #4 A Share usage data switch in Settings (opt-out) stops all events; its design comes from a mockup the developer picked
- [ ] #5 PrivacyInfo.xcprivacy declares Product Interaction and Crash Data for analytics, linked to the user, no tracking (no IDFA); coordinate with TASK-112
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Event types from docs/analytics/events.md (AnalyticsEvent, LookupKind/Source, LengthBucket).
2. Analytics class + AnalyticsSending protocol (PostHogSender real, fake in tests); injected in init of TranslationStore, SpeechPlayer, LikedStore, AccountStore (default .shared).
3. CrashReporting (Sentry) + Telemetry.start() in the app, Mac app, Share/Translate sheet, Quick explain; nothing sent in Debug unless -SaynataSendTelemetryInDebug YES.
4. Sources: app, copied, share, translate_sheet, intent, panel, services.
5. Settings Privacy card with 'Share usage data' (developer picked the Privacy card option, 2026-11-04).
6. PrivacyInfo.xcprivacy: Product Interaction + Crash Data; Sentry/PostHog Swift packages on the 4 targets; keys in Info.plists.
7. Tests (AnalyticsTests) and docs (events.md, doc-24, doc-7, doc-9).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-04: Built in a Linux cloud session without Xcode or a Swift compiler: NOT compiled, NOT tested yet. SDK APIs were checked against posthog-ios 3.93.4 and sentry-cocoa 9.32.0 source. project.pbxproj edited by hand (IDs 7D00...), parsed OK with the pbxproj Python library; Package.resolved not updated (Xcode resolves on first open). Settings design: developer picked 'New Privacy card' (doc-7). Crash Data is declared NOT linked (Sentry gets no user), Product Interaction linked (identify by user id): AC 5 says both linked; check with TASK-112. cache_hit not sent by iOS (client cannot tell a server cache hit). Changing the language on a shown sentence sends a second lookup_done. signed_in has no reason property on iOS.
<!-- SECTION:NOTES:END -->
