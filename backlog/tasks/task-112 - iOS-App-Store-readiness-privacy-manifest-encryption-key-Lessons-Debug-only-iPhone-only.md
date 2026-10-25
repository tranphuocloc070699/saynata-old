---
id: TASK-112
title: >-
  iOS: App Store readiness (privacy manifest, encryption key, Lessons Debug
  only, iPhone only)
status: To Do
assignee: []
created_date: '2026-10-24 18:04'
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
- [ ] #1 PrivacyInfo.xcprivacy ships in the app and both extensions (UserDefaults CA92.1, file timestamp C617.1, email, user ID and user content for app functionality, no tracking)
- [ ] #2 ITSAppUsesNonExemptEncryption is NO in the app and both extensions
- [ ] #3 Lessons files compile only in Debug
- [ ] #4 TARGETED_DEVICE_FAMILY is 1 (iPhone only)
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
