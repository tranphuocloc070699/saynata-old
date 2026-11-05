---
id: TASK-112.3
title: 'Backend + iOS: Revoke Sign in with Apple tokens when the account is deleted'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-04T15:23:00Z'
updated_date: '2026-11-04T16:51:00Z'
labels:
  - app-store
  - backend
dependencies: []
parent_task_id: TASK-112
priority: high
type: task
ordinal: 161000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Apple asks apps with Sign in with Apple to revoke the user's Apple tokens on account deletion. The backend deletes the account but never calls Apple (CodeRabbit App Store review 2026-11-04, finding 3).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 iOS sends the Apple authorization code at sign-in; the backend exchanges it and stores the Apple refresh token (encrypted or as a secret column)
- [x] #2 DELETE /api/me calls https://appleid.apple.com/auth/revoke for Apple accounts before deleting
- [x] #3 A failed revoke is retried or logged, and the account is still deleted
- [x] #4 Backend tests use a fake Apple endpoint; new env keys (team ID, key ID, private key) are in .env.example and doc-11
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Tests pass
- [x] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [x] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. V41: user_identity.apple_refresh_token (AES-256-GCM, base64) + apple_client_id
2. AppleTokenClient (RestClient): client_secret ES256 JWT (Nimbus), /auth/token exchange at sign-in, /auth/revoke at delete
3. POST /api/auth/apple takes optional authorizationCode; failed exchange logs, sign-in still succeeds
4. AuthService.deleteAccount revokes each Apple token (2 tries, then log error) before deleting; no token = skip
5. Env: APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, APPLE_TOKEN_ENCRYPTION_KEY, APPLE_AUTH_BASE_URL; any missing = off
6. iOS/Mac send credential.authorizationCode
7. Tests with fake Apple endpoint; docs .env.example, doc-11, doc-17, doc-24, doc-7
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Backend done and tested (AppleTokenRevokeTest, RemoteAppleTokenApiTest, AppleTokenCipherTest, SocialSignInTest, AuthFlowTest, AdminUserTest: 64 tests green). V41 (V40 is taken on the f8 branches). Env keys also in docker-compose.prod.yml. iOS sends credential.authorizationCode (OtherSignInTests); AC #1 stays open until the developer runs the iOS tests in Xcode. Known gap: web Apple sign-in sends no code, so web-only Apple accounts are not revoked (doc-17 known gaps).

2026-11-04: developer tested feature/local (iOS tests and app). Left: release to main, run backend/scripts/set-apple-keys.sh on the server (PR #266), then check a real revoke in the log.
<!-- SECTION:NOTES:END -->
