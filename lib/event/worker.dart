import 'dart:async';
import 'package:flutter/services.dart';

/// Callback invoked when iOS reports that the worker has started.
typedef DraftModeEventWorkerStarted = void Function(String eventId);

/// Callback invoked while the worker is running with the remaining runtime.
typedef DraftModeEventWorkerProgress = void Function(String eventId, Duration remaining);

/// Callback invoked after iOS notifies that the worker finished successfully.
typedef DraftModeEventWorkerCompleted = void Function(String eventId, bool fromUi);

/// Callback invoked when iOS expires the worker (e.g. time budget consumed).
typedef DraftModeEventWorkerExpired = void Function(String eventId);

/// Callback invoked when the worker is cancelled before finishing.
typedef DraftModeEventWorkerCancelled = void Function(String eventId, bool fromUi);

/// Public API that bridges the Flutter side to the iOS timed worker.
///
/// It exposes a handful of static helpers to start/cancel a worker and
/// delivers lifecycle callbacks from the underlying platform channel.
class DraftModeEventWorker {
  DraftModeEventWorker._(); // coverage:ignore-line
  static const _ch = MethodChannel('timed_worker_ios/channel');

  static DraftModeEventWorkerStarted? _onStarted;
  static DraftModeEventWorkerProgress? _onProgress;
  static DraftModeEventWorkerCompleted? _onCompleted;
  static DraftModeEventWorkerExpired? _onExpired;
  static DraftModeEventWorkerCancelled? _onCancelled;

  /// Initializes the iOS bridge. Call exactly once (e.g. inside `main`).
  ///
  /// The optional callbacks allow apps to react immediately to lifecycle
  /// changes in addition to (or instead of) the broadcast stream in
  /// `DraftModeWorkerEvents`.
  static void init({
    DraftModeEventWorkerStarted? onStarted,
    DraftModeEventWorkerProgress? onProgress,
    DraftModeEventWorkerCompleted? onCompleted,
    DraftModeEventWorkerExpired? onExpired,
    DraftModeEventWorkerCancelled? onCancelled,
  }) {
    _onStarted = onStarted;
    _onProgress = onProgress;
    _onCompleted = onCompleted;
    _onExpired = onExpired;
    _onCancelled = onCancelled;

    _ch.setMethodCallHandler((call) async {
      final m = Map<String, dynamic>.from(call.arguments as Map? ?? {});
      switch (call.method) {
        case 'worker_started':
          _onStarted?.call(m['eventId'] as String);
          break;
        case 'worker_progress':
          _onProgress?.call(
            m['eventId'] as String,
            Duration(milliseconds: (m['remainingMs'] as num).toInt()),
          );
          break;
        case 'worker_completed':
          _onCompleted?.call(
            m['eventId'] as String,
            (m['fromUi'] as bool?) ?? false,
          );
          break;
        case 'worker_cancelled':
          _onCancelled?.call(
            m['eventId'] as String,
            (m['fromUi'] as bool?) ?? false,
          );
          break;
        case 'worker_expired':
          _onExpired?.call(m['eventId'] as String);
          break;
      }
    });
  }

  /// Starts a new worker on iOS for the provided [duration] and [taskId].
  /// The ID is echoed back in callbacks and events so multiple workers can be
  /// distinguished if needed.
  static Future<void> start({
    required Duration duration,
  }) {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    return _ch.invokeMethod('start', {
      'eventId': taskId,
      'durationMs': duration.inMilliseconds,
    });
  }

  /// Cancels the currently running worker, if any.
  ///
  /// Set [fromUi] to true when the user explicitly cancelled the worker so
  /// downstream listeners can tell whether automation or UI drove the action.
  static Future<void> cancel({bool fromUi = false}) => _ch.invokeMethod(
        'cancel',
        {'fromUi': fromUi},
      );

  /// Treats the running worker as completed immediately and notifies iOS.
  ///
  /// Use [fromUi] to flag whether the UI requested completion or it happened
  /// automatically (e.g. countdown elapsed and iOS called `complete`).
  static Future<void> completed({bool fromUi = false}) => _ch.invokeMethod(
        'completed',
        {'fromUi': fromUi},
      );

  /// Reads the latest worker status from iOS (useful after app relaunch).
  static Future<Map<String, dynamic>> status() async {
    final res = await _ch.invokeMethod('status');
    return Map<String, dynamic>.from(res as Map? ?? {});
  }
}
