import 'package:draftmode_ui/ui.dart';
import 'package:flutter/cupertino.dart';

import 'worker.dart';

/// Automatically prompts the user when a timed worker is still
/// running after the app resumes (or cold starts).
///
/// Place this widget inside your `MaterialApp`/`CupertinoApp` **content**—for
/// example around a page or via the `home:` parameter—so that it has access to
/// a `Navigator`. When the worker is active it shows a simple
/// `CupertinoAlertDialog` allowing the user to keep it running, submit early or
/// cancel outright.
class DraftModeWorkerWatcher extends StatefulWidget {
  /// Wraps the portion of the UI that should stay mounted while the watcher is
  /// active. Usually this is the app's `home` widget or a shell around it.
  final Widget child;

  const DraftModeWorkerWatcher({super.key, required this.child});

  @override
  State<DraftModeWorkerWatcher> createState() => _DraftModeWorkerWatcherState();
}

class _DraftModeWorkerWatcherState extends State<DraftModeWorkerWatcher>
    with WidgetsBindingObserver {
  bool _dialogOpen = false;

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
    if (_dialogOpen || !mounted) return;

    try {
      final status = await DraftModeWorker.status();
      if (!mounted || status['isRunning'] != true) {
        return;
      }

      _dialogOpen = true;
      final remaining = Duration(
        milliseconds: (status['remainingMs'] as num?)?.toInt() ?? 0,
      );

      final taskId = status['taskId']?.toString();
      final confirm = await DraftModeUIDialog.show(
        context: context,
        title: 'Active Worker',
        message: 'Task: $taskId is still running. Submit now?',
        autoConfirm: remaining,
      );
      if (confirm == true) {
        await DraftModeWorker.completed();
      } else if (confirm == false) {
        await DraftModeWorker.cancel();
      }
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'draftmode_worker',
          context: ErrorDescription('while checking DraftModeWorker status'),
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: return child directly → context is always valid
    return widget.child;
  }
}
