# 08. Product analytics (GA4, PostHog)

## Pick one

| | GA4 | PostHog |
|---|---|---|
| Best for | Marketing site traffic, ads, SEO | Product use: funnels, retention, feature flags, session replay |
| Free tier | Free, sampled at scale | 1M events/month free, open source, EU hosting option |
| Privacy | Needs a cookie banner in the EU | Can run cookieless; self-host possible |
| Mobile | Firebase SDK | iOS SDK |

For an app (not a marketing site), **PostHog** is usually the better first choice: one tool for events,
feature flags and A/B tests. Use GA4 on the marketing site if you buy ads. The kit's `track()` sends to
`gtag` if present. Swap in `posthog.capture` in that one function.

## Tracking plan: write it before you add events

The plan lives **in code** (`web/src/lib/analytics.ts`), so a typo is a compile error:

```ts
type Events = {
  note_created: { title_length: number }
  note_opened: { note_id: number }
}
```

Rules:
- Names are `object_action`, past tense, snake_case: `signup_completed`, `note_created`, `plan_upgraded`.
  Never `Click Button`, `createNote`, or `note-create`.
- The same name on every platform (web, iOS, backend). Keep one list in the repo, for example `docs/tracking-plan.md`.
- Properties are ids, counts and enums. **Never** free text, emails, names, or anything a user typed.
- Track outcomes (`note_created`), not clicks (`add_button_clicked`). Add click events only for a specific question.
- Each event answers a question you wrote down: "Do people who create 3 notes in week 1 stay?"
- Send important events from the **backend** (payment, signup). Ad blockers stop 20-40% of browser events.

## Start with five events

`signup_completed`, `onboarding_completed`, `<core_action>_completed` (the thing your app is for),
`subscription_started`, `account_deleted`. With these you get a funnel, activation, and retention.

## Real examples

- PostHog docs, *Product analytics best practices* (naming: `category:object_action`).
- Segment, *Naming conventions* (Object Action, past tense).
- Google, *GA4 recommended events* (use their names when one fits: `sign_up`, `purchase`).
