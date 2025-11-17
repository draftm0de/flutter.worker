import 'dart:async';

import 'package:flutter/widgets.dart';

import 'worker.dart';

/// Signature used when the watcher detects an active worker.
typedef DraftModeWorkerWatcherCallback = FutureOr<void> Function(
  Map<String, dynamic> worker,
);

/// Monitors the worker state whenever the app resumes (or cold starts) and
/// invokes [onActiveWorker] with the latest worker status when it is still
/// running.
///
/// Place this widget inside your `MaterialApp`/`CupertinoApp` **content**—for
/// example around a page or via the `home:` parameter—and inject whatever
/// dependencies your callback needs (such as a navigator key or service).
class DraftModeWorkerWatcher extends StatefulWidget {
  /// Wraps the portion of the UI that should stay mounted while the watcher is
  /// active. Usually this is the app's `home` widget or a shell around it.
  final Widget child;

  /// Invoked whenever the watcher discovers that a worker is still active.
  ///
  /// Use this to drive app-specific business logic (e.g. showing dialogs or
  /// navigating) and decide whether to cancel/complete the worker.
  final DraftModeWorkerWatcherCallback onActiveWorker;

  const DraftModeWorkerWatcher({
    super.key,
    required this.child,
    required this.onActiveWorker,
  });

  @override
  State<DraftModeWorkerWatcher> createState() => _DraftModeWorkerWatcherState();
}

class _DraftModeWorkerWatcherState extends State<DraftModeWorkerWatcher>
    with WidgetsBindingObserver {
  bool _handlingWorker = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Also check after cold start once the first frame has rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWorkerOnResume();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWorkerOnResume();
    }
  }

  Future<void> _checkWorkerOnResume() async {
    if (_handlingWorker || !mounted) return;

    try {
      final status = await DraftModeWorker.status();
      if (!mounted || status['isRunning'] != true) {
        return;
      }
      _handlingWorker = true;
      await Future.sync(
        () => widget.onActiveWorker(
          Map<String, dynamic>.from(status),
        ),
      );
    }
    // coverage:ignore-start
    catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'draftmode_worker',
          context: ErrorDescription('while checking DraftModeWorker status'),
        ),
      );
    }
    // coverage:ignore-end
    finally {
      _handlingWorker = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: return child directly → context is always valid
    return widget.child;
  }
}
