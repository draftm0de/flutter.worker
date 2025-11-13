# DraftMode Worker (iOS)

DraftMode Worker is a lightweight Flutter plugin that wraps iOS background tasks
with a simple timer-driven API. It ships with:

- `DraftModeWorker` – starts/cancels workers and exposes lifecycle callbacks via a platform channel.
- `DraftModeWorkerEvents` – a broadcast stream so multiple widgets/services can observe the worker without wiring direct callbacks.
- `DraftModeWorkerWatcher` – a widget that surfaces a reminder dialog when the app resumes while a worker is still running.

The `example/` app demonstrates how to hook those pieces into a Cupertino UI. It now consumes the shared `DraftModeExamplePageWidget` from `package:draftmode/example.dart` so every plugin demo in the DraftMode workspace can reuse the same header/branding without duplicating code.

## Quick Start

```dart
import 'package:draftmode/worker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DraftModeWorker.init(
    onStarted: (id) => DraftModeWorkerEvents.dispatch(WorkerEvent.started(id)),
    onProgress: (id, remaining) =>
        DraftModeWorkerEvents.dispatch(WorkerEvent.progress(id, remaining)),
    onCompleted: (id) =>
        DraftModeWorkerEvents.dispatch(WorkerEvent.completed(id)),
    onExpired: (id) =>
        DraftModeWorkerEvents.dispatch(WorkerEvent.expired(id)),
  );

  runApp(const MyApp());
}
```

### Launch a worker

```dart
await DraftModeWorker.start(
  taskId: 'my-id',
  duration: const Duration(minutes: 2),
);
```

### Cancel the worker

```dart
await DraftModeWorker.cancel();
```

### Subscribe to lifecycle events

```dart
final sub = DraftModeWorkerEvents.stream.listen((event) {
  switch (event.type) {
    case WorkerEventType.progress:
      debugPrint('Remaining ${event.remaining}');
      break;
    case WorkerEventType.completed:
      debugPrint('Done!');
      break;
    default:
      break;
  }
});
```

### Prompt users on resume

Embed `DraftModeWorkerWatcher` inside your app's `home` (or any widget that sits
under a `Navigator`) to gently remind users about an in-flight worker after the
app returns to the foreground:

```dart
return CupertinoApp(
  home: DraftModeWorkerWatcher(
    onSubmitNow: (taskId) async {
      await flushPendingDraft(taskId);
    },
    child: const DraftEditorPage(),
  ),
);
```

The watcher automatically cancels the iOS worker when the user taps **Submit
now** or **Cancel**. The optional callback is the perfect place to push any
domain-specific logic (e.g. sending the final draft to your backend).

## Example app

The `example/` folder contains a Cupertino demo that wires the plugin into a duration picker, status banner, and countdown display. It embeds the shared DraftMode example shell via `package:draftmode/example.dart`, so all branding/UI chrome now lives in the dedicated `draftmode_example` package. Assets bundled with that package are loaded by specifying `package: 'draftmode_example'` in `Image.asset`, which happens inside the shared widget—no extra work is required in this repo's `example/` after importing the facade.

## Development Notes

- The example depends on the facade package (`package:draftmode/worker.dart` and `package:draftmode/example.dart`), mirroring real app usage.
- Run `flutter analyze lib example/lib` before committing; keep both plugin and demo lint-clean.
- When tweaking native iOS code, run `flutter clean` if you encounter stale build artifacts.

## License

MIT © DraftMode
