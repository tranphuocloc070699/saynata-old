---
id: TASK-102.9
title: 'Web Download page for iOS, macOS and the browser extension'
status: To Do
assignee: []
created_date: '2026-10-25 11:51'
updated_date: '2026-10-25 12:00'
labels:
  - web
dependencies: []
parent_task_id: TASK-102
ordinal: 137000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The website has no place that tells a learner Saynata also exists on iPhone, Mac and as a Chrome extension. None of the three is in a store yet (iOS waits on TASK-112, the extension and Mac app have no store task), so the page must work before any link exists and each link must turn on later with a one-line change when the developer ships that platform. Layout references from Mobbin (2026-10-25): stacked cards (hilos, Fabric, Clay), three cards (NordVPN, Airtable, Loom), compact list with a smart main button (Linear, Craft). Mockup first; the developer picks a layout before code.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All platform links and states live in one config file; each platform is either Coming soon (no link) or Live (store link)
- [ ] #2 /download shows iOS, macOS and the browser extension in the layout the developer chose, in light and dark, at phone and wide width
- [ ] #3 A Coming soon platform renders no link; a Live one opens its store URL in a new tab
- [ ] #4 The main button matches the visitor's device (iPhone, Mac, Chrome); desktop visitors get a QR code for iOS once it is Live
- [ ] #5 The site has an entry point to /download (icon-only if it is a button)
- [ ] #6 Vitest covers the soon/live states and device detection
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Tests pass
- [ ] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [ ] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Mockup chosen 2026-10-25 (developer): layout A, stacked cards. Each card: picture tile, platform name, one line on what it does there (iPhone: Share from Safari, hear and practise; Mac: ⌥⇧Space explains the selection; extension: select English on any page), then the official store badge when Live or a Coming soon pill. Desktop iOS card shows a QR code once Live. Sage and Teal tokens, serif heading 'Take Saynata everywhere'.
<!-- SECTION:NOTES:END -->
