# 05. iOS: SwiftUI, Swift 6

Template: `stacks/ios/`. **Not compiled here** (this kit was built on Linux, without Xcode). Before you
use it, run `make -C ios check` once on your Mac and fix what Xcode reports.

## Structure

```
ios/
├── project.yml            XcodeGen spec → App.xcodeproj (generated, git-ignored)
├── Config/*.xcconfig      API_BASE_URL, APP_ENV, SENTRY_DSN per build (Local.xcconfig is git-ignored)
├── App/App.swift          @main: reads config, starts Sentry, builds stores, injects them
├── Core/                  APIClient (+ HTTPTransport protocol), AppConfig, Log (os.Logger)
├── Features/Notes/        Note (model), NotesStore (@Observable @MainActor), NotesView
└── Tests/                 Swift Testing, with a FakeTransport
```

## Why these choices

| Choice | Why |
|---|---|
| **XcodeGen** (`project.yml`) | `project.pbxproj` is thousands of lines that no one can review, and agents break it. A 40-line YAML is easy to read. Tuist is a stronger option for big apps |
| `@Observable` + `@MainActor` stores | The modern Observation framework. UI state stays on the main actor. No Combine |
| Inject with `.environment(store)` | The same pattern as Saynata. Previews and tests can pass any store |
| Protocols around system APIs (`HTTPTransport`) | Tests use fakes, so there is no network in tests |
| Swift 6 + `SWIFT_STRICT_CONCURRENCY=complete` | Data races are compile errors, not random crashes |
| Warnings as errors | Agents leave warnings behind. This stops them |
| Swift Testing (`@Test`, `#expect`) | Clearer than XCTest, and supports parameterized tests |
| `os.Logger` with privacy markers | Logs are free and on the device; user data is hidden in release |
| No API keys in the app | An app binary can be read. Call your backend, which holds the keys (Saynata does this) |

## Habits

- Views stay thin: layout + call the store. Logic lives in the store, and the store has tests.
- One `Task` per user action. Use `.task {}` for loading (it is cancelled when the view goes away).
- Icon-only buttons always get `.accessibilityLabel` (a Saynata UI rule, and good practice).
- Always use the same simulator for tests and screenshots (Saynata: iPhone 16 Pro, iOS 18.5), so results match.
- Ship through TestFlight from CI (Xcode Cloud, or fastlane on GitHub Actions `macos-15`) once you have users.

## Real examples

- `Dimillian/IceCubesApp`: a large open-source SwiftUI app with `@Observable` and environment injection.
  This repo has a report on it: `IceCubesApp_Architecture_Report.md`.
- `nalexn/clean-architecture-swiftui`: layers, DI and testing in SwiftUI.
- `pointfreeco/isowords`: a full game with heavy modularisation (shows how far you can go).
- Apple, *Migrating to Swift 6*; WWDC25 *Explore concurrency in SwiftUI*.
- This repo: `EnglishTranslation/` (Saynata iOS): `Stores/`, `Speech/` behind protocols, and its Swift Testing suites.
