# Repository Guidelines

## Project Structure & Module Organization
- Root `lib/` contains the plugin sources: `lib/worker.dart` exposes the platform API and re-exports `lib/worker/event.dart` for lifecycle events. 
- The facade package lives in `../flutter/flutter`, exporting `package:draftmode/worker.dart`. 
- `example/` hosts the Cupertino demo (`example/lib/main.dart`, `example/lib/page.dart`) plus assets under `example/assets/`.

## Build, Test, and Development Commands
- `flutter pub get` (run in both root and `example/`) installs dependencies.
- `flutter analyze lib example/lib` checks style and null-safety issues for both plugin and demo.
- `flutter test` (root) executes package unit tests; `flutter test` inside `example/` runs demo-level tests when present.
- `flutter test --coverage` must be used when generating reports; follow it with `genhtml coverage/lcov.info -o coverage/html` so contributors can inspect HTML results.

## Coding Style & Naming Conventions
- Follow Dart style: two-space indentation, camelCase for vars/methods, PascalCase for types. 
- Keep widget trees readable; add concise comments for complex sections only. 
- Prefer importing via the facade (`package:draftmode/worker.dart`) inside examples.

## Testing Guidelines
- Use Flutter’s `test` package; place tests under `test/` mirroring source paths (e.g., `test/worker/worker_test.dart`).
- Name tests descriptively (`'start() sends duration'`).
- Run `flutter test` before submitting PRs; whenever coverage is requested, target ~100% by exercising all public code paths and regenerating both LCOV and HTML reports as noted above.

## Commit & Pull Request Guidelines
- Use present-tense, concise commit messages (e.g., `Add event bus docs`).
- PRs should include: summary of changes, testing evidence (`flutter analyze`, `flutter test`), and screenshots/GIFs for UI tweaks. Link to issue numbers where applicable.

## Additional Notes
- Example assets live in `example/assets/images/`; update `pubspec.yaml` when adding new files.
- When editing native iOS code, run `flutter clean` if build artifacts behave oddly.
