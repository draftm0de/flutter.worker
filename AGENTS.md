# Repository Guidelines

## Project Structure & Module Organization
- `lib/worker.dart` is the public surface; it re-exports `lib/worker/event.dart` (event stream) and `lib/worker/watcher.dart` (UI helper). Keep new APIs under `lib/worker/` and mirror them in `test/` for parity.
- `example/` contains the Cupertino demo (`example/lib/main.dart`), plus its `ios/` runner and assets. The sample always imports via `package:draftmode/worker.dart` so it reflects real app usage.
- Shared DraftMode packages live under `../flutter/*` (e.g., `../flutter/ui`, `../flutter/localization`). Use `path` dependencies and `dependency_overrides` so every package resolves to the same local checkout.

## Build, Test, and Development Commands
- `flutter pub get` (run here and in `example/`) installs deps and updates generated plugin registries.
- `flutter analyze lib example/lib` lints both plugin + demo to catch null-safety, formatting, and import issues.
- `flutter test` runs unit/widget suites. For coverage, run `flutter test --coverage && genhtml coverage/lcov.info -o coverage/html` and share the HTML folder; this is mandatory whenever `CHANGELOG.md` is touched so reviewers always get fresh reports.

## Coding Style & Naming Conventions
- Follow Dart defaults: two-space indentation, camelCase members, PascalCase types. Keep widget trees readable and only add comments for non-obvious flows (e.g., lifecycle observers).
- UI code should import through the facade (`package:draftmode/worker.dart`) rather than relative paths. Dialog text should come from localization packages when available.
- Prefer small, composable widgets or helpers over deeply nested build methods.

## Testing Guidelines
- Place tests under `test/`, mirroring source structure (`lib/worker/watcher.dart` → `test/watcher_test.dart`). Use `TestDefaultBinaryMessengerBinding` to stub MethodChannels and clean them up in `tearDown`.
- Name tests with intent-first descriptions such as `'confirming submits worker'`.
- Run `flutter test` at the root; when demo behavior changes, run `flutter test` inside `example/` as well.

## Commit & Pull Request Guidelines
- Commit messages should be present-tense and scoped (`Add worker watcher dialog`). Avoid mixing unrelated refactors.
- PRs must summarize changes, list analyzer/test runs, and include screenshots/GIFs for UI adjustments. Link related issues/tickets and mention coverage output when requested.

## Troubleshooting & Environment Tips
- If `flutter pub get` reports conflicting local packages, align every `path` dependency (worker, ui, localization, facade) to the same repo checkout and add `dependency_overrides` in consumers when needed.
- After editing native iOS code in `example/ios/`, run `flutter clean` if Xcode builds pick up stale artifacts.
