## [Unreleased]
### Changed
- Document how the shared DraftMode example shell loads its assets and ensure the example `.gitignore` only tracks source files.
- Add repo-level ignore rules so generated Flutter/PODS artifacts from `example/ios` stay out of version control.
- Summarize the README's example section now that the local `lib/widget/page.dart` scaffold moved into the shared package.
- Teach the iOS plugin a `completed` MethodChannel method, reuse the Swift completion path, and expose the Dart `DraftModeWorker.completed()` helper in docs/tests so early submission no longer throws `MissingPluginException`.
- Replace the watcher’s imperative dialog with the shared `DraftModeUIDialog`, simplify the API (no extra callbacks), and cover the flow with widget tests.

## 0.1.0
- Initial public release of DraftMode Worker
  - Exposes `DraftModeWorker` API to start/cancel iOS background timers.
  - Adds `DraftModeWorkerEvents` broadcast stream for lifecycle updates.
  - Includes Cupertino demo app with numeric duration picker, status banner, and branding header.
  - Provides unit tests (100% coverage) and coverage instructions.
