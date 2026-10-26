### iOS (`ios/`, SwiftUI, iOS 18, Swift 6 strict concurrency, XcodeGen, Swift Testing)

- The Xcode project is generated from `project.yml` (`make -C ios project`); never commit `*.xcodeproj`.
  Add files by putting them in a folder listed in `project.yml`.
- Code by feature: `Features/<Feature>/` holds its models, `@Observable @MainActor` store, and views.
  Shared code in `Core/` (API client, config, logging). Views hold no logic beyond layout and calling the store.
- Stores are injected with `.environment(store)`; every `#Preview` adds the stores it needs.
- System APIs (network, clock, files, speech) sit behind a small protocol; tests pass a fake.
- Network only through `APIClient`; it maps Problem Details to `APIError(code:)`.
- Config from `Config/*.xcconfig` → Info.plist → `AppConfig`. No API keys in the app (a binary can be read):
  call your backend, which holds the keys.
- Logs with `os.Logger` (`Log.api`), privacy markers on user data.
- Tests with Swift Testing (`@Test`, `#expect`). Run one suite: `make -C ios test S=NotesStoreTests`.
