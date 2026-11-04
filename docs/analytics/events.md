# Saynata events (PostHog) and error rules (Sentry)

The one list of usage events for every client (TASK-128.1). iOS/Mac (TASK-128.3), web (TASK-128.4) and the
extension (TASK-128.5) send **exactly these names and properties**. To add or rename an event, change this file
first, in the same PR as the code. Keys and hosts: doc-24, sections "Error reporting" and "Usage tracking".

Last updated: 2026-11-04.

## Privacy rule (read this first)

**Never send what the learner looked up, typed, selected or copied.** Not the word, not the sentence, not the
meaning, not a page URL, not an email. An event may only carry:

- `kind` (word, phrase, sentence), `source` (where the lookup started), a **length bucket**, and `cache_hit`;
- fixed choices from this file (a language code, a button part, a sign-in method, a score number);
- the user ID (a number from our backend) after sign-in, through `identify`. Never the email or a name.

The same rule applies to Sentry: no request bodies, no query strings, no word in the URL path (each part has a
scrub: `web/src/lib/sentry.ts`, `extension/src/shared/sentry.ts`, backend `common/SentryScrub`). Session Replay
is off in PostHog, because it would record the screen text.

When a property is not on this page, do not send it. A reviewer checks every `capture` call against this list.

### Length bucket

`length` is counted in characters of the trimmed text (UTF-16, like the 500-character limit):

| `length` | Characters |
|---|---|
| `xs` | 1-20 (one word or a short phrase) |
| `s` | 21-80 (a short sentence) |
| `m` | 81-200 |
| `l` | 201-500 |

## Properties on every event

Set once as super properties (registered at start), not passed on each call:

| Property | Values | Notes |
|---|---|---|
| `platform` | `ios`, `mac`, `web`, `extension` | The dashboard filter (TASK-128.6) |
| `app_version` | for example `1.4.0` | Marketing version; the extension uses its manifest version |
| `signed_in` | `true`, `false` | Changes on sign-in and sign-out |

PostHog adds `distinct_id` itself: an anonymous ID, then the user ID after `identify`.

## Values of `source`

Where a lookup started. Each client sends only its own values.

| `source` | Platform | Where |
|---|---|---|
| `app` | ios, mac | Typed or pasted in the main screen |
| `copied` | ios | Back Tap or a deep link put copied text in the app (`CopiedTextLaunch`) |
| `share` | ios | Share extension |
| `translate_sheet` | ios | The system Translate sheet (TranslationExtension, default translation app) |
| `intent` | ios, mac | App Intents: Explain copied text, Quick explain |
| `panel` | mac | Floating panel (⌥⇧Space) |
| `services` | mac | The Services menu item |
| `extension` | extension | The card on a web page |
| `web` | web | A lookup on the website (when it exists) |

## The events

Twelve events, plus one reserved for later. "Question" says what each one answers:

- **Adoption**: does a learner find this feature at all? (count of people who did it at least once)
- **Repeat use**: do they come back to it? (retention, times per week)
- **Explicit like**: did they say they want to keep it? (Like, sign-in)
- **Product goal**: does explain-first work? (do people need the target-language line?)

| # | Event | Properties | Sent when | Question | Clients |
|---|---|---|---|---|---|
| 1 | `lookup_done` | `kind`: `word` \| `phrase` \| `sentence`; `source` (above); `length` (bucket); `cache_hit`: bool, left out when the client cannot tell; `lang`: target-language code (`vi`, `ko`...); `row_start`: `open` \| `closed` | A result is on screen (word card or full sentence result). Once per lookup, not on prefetch while typing | Adoption and repeat use of the core feature; which entry points people use | all |
| 2 | `lookup_failed` | `kind`; `source`; `reason`: `sign_in_required` \| `daily_limit` \| `not_english` \| `offline` \| `server` | The result area shows an error instead of a result | Where people get stuck; how often the guest limit stops them | all |
| 3 | `listen_tapped` | `part`: `word` \| `example` \| `meaning` \| `sentence`; `kind` | The Listen icon starts reading (not when it stops) | Adoption and repeat use of Listen (F3) | ios, mac, extension |
| 4 | `language_row_opened` | `lang`; `kind` | The learner taps the target-language row open. Not when it opens by itself (`alwaysOpen` or remembered) | **Product goal**: language-row open rate | ios, mac, extension |
| 5 | `item_liked` | `kind` | The star turns on (also the like that waited for sign-in) | Explicit like | ios, mac, web |
| 6 | `item_unliked` | `kind` | The star turns off, or a swipe in the Liked list | Like quality (liked then removed) | ios, mac, web |
| 7 | `sentence_word_opened` | `has_entry`: bool (the word was in the bundle) | A word in a sentence result is tapped and its card opens | Adoption of words inside sentences | ios, mac |
| 8 | `suggestion_tapped` | none | A "did you mean" word is tapped | Is spelling help used | ios, mac |
| 9 | `history_opened` | `tab`: `history` \| `liked` | History or Liked opens | Do people go back to old results (repeat use) | ios, mac, web |
| 10 | `quick_explain_used` | `source`: `intent` | Quick explain shows its card (inside Shortcuts or Siri, the app stays closed) | Adoption of the shortcut | ios |
| 11 | `language_changed` | `lang` (the new one) | The learner picks another target language | Which languages to support next | ios, mac, extension, web |
| 12 | `signed_in` | `method`: `email_code` \| `email_link` \| `google` \| `apple`; `reason`: `limit` \| `like` \| `settings` \| `web` | Sign-in succeeded (also sign-up). Call `identify(user_id)` first | Explicit commitment; which prompt brings sign-ins | all |
| 13 | `speak_scored` | `score`: 0-100 (whole number); `kind` | **Reserved, not built yet**: the "say the meaning" practice gives a score (doc-1) | Adoption and repeat use of speaking practice | (later) |

Notes:

- `lookup_done` with `kind: phrase` is a 2-6 word phrase shown as a word card (TASK-83.10). A non-English word
  that opens an English word card (TASK-114) is `kind: word`.
- `row_start` is how the language row started on that result. `closed` results are the base for the open rate.
- Signing out calls `reset()`, so the next events get a new anonymous ID.
- No event for "app opened": PostHog's own lifecycle events (`Application Opened` on iOS/Mac, `$pageview` on web)
  cover it. Retention uses `lookup_done` as the "active" event, the same on every platform.

## Opt-out and Debug

- iOS/Mac: Settings has a "Share usage data" switch (on by default, opt-out). Off: no events at all (PostHog
  `optOut()`); crash reports to Sentry stay, without user content. Design from a mockup (TASK-128.3).
- Debug builds and tests send nothing unless turned on (iOS: a launch argument; web and extension: no key in env).

## PostHog insights to build (TASK-128.6)

One dashboard, "Saynata: which features users like", with a `platform` filter on every insight.

| Insight | Type | How | Question |
|---|---|---|---|
| Weekly active learners | Trends | Unique users with `lookup_done`, weekly | Overall use |
| Feature adoption % | Trends, formula | For each of `listen_tapped`, `language_row_opened`, `item_liked`, `sentence_word_opened`, `history_opened`, `quick_explain_used`: unique users / unique users with `lookup_done`, last 30 days | Adoption |
| Entry points | Trends, breakdown | `lookup_done` broken down by `source` | Which ways in people use |
| Week-2 retention by feature | Retention | Start: first time doing the feature; return: `lookup_done` in week 2. One series per feature | Repeat use |
| Feature repeat rate | Stickiness | Days per week with each feature event | Repeat use |
| **Language-row open rate** | Trends, formula | `language_row_opened` count / `lookup_done` count where `row_start = closed`, broken down by `kind` and `lang` | Product goal: explain first, translate last. Low is good |
| Likes | Trends | `item_liked` minus `item_unliked`, broken down by `kind` | Explicit like |
| Sign-in funnel | Funnel | `lookup_failed` (`reason = sign_in_required`) then `signed_in` within 1 day | Does the guest limit turn into accounts |
| Cache hits | Trends, breakdown | `lookup_done` by `cache_hit` | Cost check (cache-first) |
| Errors seen by learners | Trends, breakdown | `lookup_failed` by `reason` | Where people get stuck |

Read these only after about 50 real users; before that the numbers move too much to mean anything.
Usage is not liking: read adoption, repeat use and Likes together before deciding a feature is loved.
