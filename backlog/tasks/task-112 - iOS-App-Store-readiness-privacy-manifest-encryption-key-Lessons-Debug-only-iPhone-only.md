---
id: TASK-112
title: >-
  iOS: App Store readiness (privacy manifest, encryption key, Lessons Debug
  only, iPhone only)
status: Done
assignee: []
created_date: '2026-10-24 18:04'
updated_date: '2026-11-09 11:09'
labels:
  - ios
dependencies: []
ordinal: 124000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Code-side blockers found in the App Store readiness check: no privacy manifest, ITSAppUsesNonExemptEncryption missing, the Lessons practice files shipped in Release, and the app was set for iPad too. The icon on feature/local already has no alpha channel.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 PrivacyInfo.xcprivacy ships in the app and both extensions (UserDefaults CA92.1, file timestamp C617.1, email, user ID and user content for app functionality, no tracking)
- [x] #2 ITSAppUsesNonExemptEncryption is NO in the app and both extensions
- [x] #3 Lessons files compile only in Debug
- [x] #4 TARGETED_DEVICE_FAMILY is 1 (iPhone only)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [x] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [x] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-09 check: all 4 points were already built in 73580d2a (2026-10-25, in main). Release build for the iPhone 16 Pro simulator (BUILD SUCCEEDED) shows: PrivacyInfo.xcprivacy in the app, ShareExtension.appex and TranslationExtension.appex; UIDeviceFamily [1] and ITSAppUsesNonExemptEncryption false in all three Info.plists; no Lessons symbols or strings in the Release binary. Only file-date API use since then is MediaFileCache (own cache folder), covered by C617.1. When Sentry/PostHog land (TASK-128.3, PR #262), the manifest needs crash data and product interaction entries.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Privacy manifest, encryption key NO, Lessons Debug-only and iPhone-only shipped in 73580d2a. Verified on 2026-11-09 by inspecting a Release simulator build bundle.
<!-- SECTION:FINAL_SUMMARY:END -->
