import 'dart:async';

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

  /// Optional callback that fires when the user chooses **Submit now**.
  ///
  /// The watcher already cancels the iOS task; this hook gives the host app a
  /// chance to flush any pending work immediately afterwards.
  final FutureOr<void> Function(String? taskId)? onSubmitNow;

  const DraftModeWorkerWatcher({
    super.key,
    required this.child,
    this.onSubmitNow,
  });

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

      await _showWorkerDialog(
        context,
        taskId: status['taskId']?.toString(),
        remaining: remaining,
        onSubmitNow: widget.onSubmitNow,
      );
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

Future<void> _showWorkerDialog(
  BuildContext context, {
  required String? taskId,
  required Duration remaining,
  FutureOr<void> Function(String? taskId)? onSubmitNow,
}) async {
  final remainingText =
      '${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';

  final action = await showCupertinoDialog<WorkerAction>(
    context: context, // ← CORRECT, uses current screen context
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Active Worker'),
      content: Text(
        'Task: $taskId\n'
        'Remaining: $remainingText',
      ),
      actions: [
        CupertinoDialogAction(
          child: const Text('Leave running'),
          onPressed: () => Navigator.of(ctx).pop(WorkerAction.keep),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          child: const Text('Submit now'),
          onPressed: () => Navigator.of(ctx).pop(WorkerAction.submit),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(ctx).pop(WorkerAction.cancel),
        ),
      ],
    ),
  );

  // Handle user choice
  switch (action) {
    case WorkerAction.submit:
      await DraftModeWorker.cancel();
      if (onSubmitNow != null) {
        await Future.sync(() => onSubmitNow(taskId));
      }
      break;
    case WorkerAction.cancel:
      await DraftModeWorker.cancel();
      break;
    case WorkerAction.keep:
    case null:
      break;
  }
}

/// Possible actions surfaced by the watcher dialog.
enum WorkerAction { keep, submit, cancel }
