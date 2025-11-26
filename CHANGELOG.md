## [Unreleased]
### Changed
- Document how the shared DraftMode example shell loads its assets and ensure the example `.gitignore` only tracks source files.
- Add repo-level ignore rules so generated Flutter/PODS artifacts from `example/ios` stay out of version control.
- Summarize the README's example section now that the local `lib/widget/page.dart` scaffold moved into the shared package.
- Teach the iOS plugin a `completed` MethodChannel method, reuse the Swift completion path, and expose the Dart `DraftModeWorker.completed()` helper in docs/tests so early submission no longer throws `MissingPluginException`.
- Require a new `onEvent` callback on `DraftModeWorkerWatcher` so apps control how to handle active workers while still getting the status payload when the app resumes (the callback now receives only the worker map so apps can inject their own navigator dependencies).
- Expand the `DraftModeEventWatcher.onEvent` signature to surface a `DraftModeEventElement`, exposing the original payload plus its creation timestamp/optional delay for consumers that need metadata.
- Allow `DraftModeWorker.cancel()`/`.completed()` to accept an optional `fromUi` flag, propagate it through the MethodChannel/iOS plugin, emit a `worker_cancelled` event, and expose the origin via `onCompleted`/`onCancelled` callbacks plus `WorkerEvent.fromUi`.

## 0.1.0
- Initial public release of DraftMode Worker
  - Exposes `DraftModeWorker` API to start/cancel iOS background timers.
  - Adds `DraftModeWorkerEvents` broadcast stream for lifecycle updates.
  - Includes Cupertino demo app with numeric duration picker, status banner, and branding header.
  - Provides unit tests (100% coverage) and coverage instructions.
