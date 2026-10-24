---
id: TASK-102.5
title: Google sign-in branding and brand verification
status: To Do
assignee: []
created_date: '2026-10-24 17:30'
labels: []
dependencies:
  - TASK-102.4
references:
  - >-
    https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid
parent_task_id: TASK-102
ordinal: 124000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The developer wants the Saynata logo shown when people sign in with Google. Google shows the logo only after brand verification, and the brand belongs to the whole Google Cloud project, so the iOS Google sign-in gets the logo too. The web OAuth client already exists (2026-10-25): 324827560698-cb0snbai8ugvrvhbtbdkfp585riflmki.apps.googleusercontent.com (origins https://saynata.com, http://localhost:3000, http://localhost). Mostly console work by the developer; an agent can add the Search Console DNS TXT record with scripts/dns.sh once the developer sends the value.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Google Auth Platform → Branding has app name Saynata, a 120×120 px square logo (under 1 MB), support email, home page https://saynata.com, privacy and terms URLs, authorized domain saynata.com
- [ ] #2 saynata.com is verified in Google Search Console (DNS TXT record on Cloudflare)
- [ ] #3 Brand verification is submitted in Verification Center and approved
- [ ] #4 The Google sign-in popup on web and on iOS shows the Saynata logo
- [ ] #5 doc-11 section 13 records the web client ID and the branding steps
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->
