import 'dart:async';

import '../worker/event.dart';
import '../worker/worker.dart' as timed;

/// Callback invoked when iOS reports that the worker has started.
typedef DraftModeEventWorkerStarted = void Function(String eventId);

/// Callback invoked while the worker is running with the remaining runtime.
typedef DraftModeEventWorkerProgress = void Function(
  String eventId,
  Duration remaining,
);

/// Callback invoked after iOS notifies that the worker finished successfully.
typedef DraftModeEventWorkerCompleted = void Function(
  String eventId,
  bool fromUi,
);

/// Callback invoked when iOS expires the worker (e.g. time budget consumed).
typedef DraftModeEventWorkerExpired = void Function(String eventId);

/// Callback invoked when the worker is cancelled before finishing.
typedef DraftModeEventWorkerCancelled = void Function(
  String eventId,
  bool fromUi,
);

/// Public API that bridges the Flutter side to the iOS timed worker specifically
/// for DraftMode event queue usage. It reuses the core `DraftModeWorker`
/// plumbing so the app only needs a single platform channel handler.
class DraftModeEventWorker {
  DraftModeEventWorker._(); // coverage:ignore-line

  static final Map<Object, _DraftModeEventWorkerCallbacks> _listeners =
      <Object, _DraftModeEventWorkerCallbacks>{};
  static final Object _defaultToken = Object();
  static StreamSubscription<WorkerEvent>? _sub;

  /// Initializes the worker listener. Safe to call multiple times—provide a
  /// unique [token] if you need to register without clobbering other
  /// subscribers (otherwise subsequent calls override the previous callbacks).
  static void init({
    Object? token,
    DraftModeEventWorkerStarted? onStarted,
    DraftModeEventWorkerProgress? onProgress,
    DraftModeEventWorkerCompleted? onCompleted,
    DraftModeEventWorkerExpired? onExpired,
    DraftModeEventWorkerCancelled? onCancelled,
  }) {
    final key = token ?? _defaultToken;
    if (_listeners.containsKey(key)) {
      _listeners[key] = _listeners[key]!.copyWith(
        onStarted: onStarted,
        onProgress: onProgress,
        onCompleted: onCompleted,
        onExpired: onExpired,
        onCancelled: onCancelled,
      );
    } else {
      _listeners[key] = _DraftModeEventWorkerCallbacks(
        onStarted: onStarted,
        onProgress: onProgress,
        onCompleted: onCompleted,
        onExpired: onExpired,
        onCancelled: onCancelled,
      );
    }

    _sub ??= DraftModeWorkerEvents.stream.listen(_handleWorkerEvent);
  }

  static void remove(Object token) {
    _listeners.remove(token);
    if (_listeners.isEmpty) {
      _sub?.cancel();
      _sub = null;
    }
  }

  static void _handleWorkerEvent(WorkerEvent event) {
    final listeners = List<_DraftModeEventWorkerCallbacks>.from(_listeners.values);
    for (final listener in listeners) {
      listener.handle(event);
    }
  }

  /// Starts (or resumes) the shared timed worker for the supplied [eventId].
  static Future<void> start({
    required String eventId,
    required Duration duration,
  }) {
    return timed.DraftModeWorker.start(taskId: eventId, duration: duration);
  }

  /// Cancels the currently running worker, if any.
  static Future<void> cancel({bool fromUi = false}) =>
      timed.DraftModeWorker.cancel(fromUi: fromUi);

  /// Treats the running worker as completed immediately and notifies iOS.
  static Future<void> completed({bool fromUi = false}) =>
      timed.DraftModeWorker.completed(fromUi: fromUi);

  /// Reads the latest worker status from iOS (useful after app relaunch).
  static Future<Map<String, dynamic>> status() => timed.DraftModeWorker.status();
}

class _DraftModeEventWorkerCallbacks {
  const _DraftModeEventWorkerCallbacks({
    this.onStarted,
    this.onProgress,
    this.onCompleted,
    this.onExpired,
    this.onCancelled,
  });

  final DraftModeEventWorkerStarted? onStarted;
  final DraftModeEventWorkerProgress? onProgress;
  final DraftModeEventWorkerCompleted? onCompleted;
  final DraftModeEventWorkerExpired? onExpired;
  final DraftModeEventWorkerCancelled? onCancelled;

  _DraftModeEventWorkerCallbacks copyWith({
    DraftModeEventWorkerStarted? onStarted,
    DraftModeEventWorkerProgress? onProgress,
    DraftModeEventWorkerCompleted? onCompleted,
    DraftModeEventWorkerExpired? onExpired,
    DraftModeEventWorkerCancelled? onCancelled,
  }) {
    return _DraftModeEventWorkerCallbacks(
      onStarted: onStarted ?? this.onStarted,
      onProgress: onProgress ?? this.onProgress,
      onCompleted: onCompleted ?? this.onCompleted,
      onExpired: onExpired ?? this.onExpired,
      onCancelled: onCancelled ?? this.onCancelled,
    );
  }

  void handle(WorkerEvent event) {
    switch (event.type) {
      case WorkerEventType.started:
        onStarted?.call(event.taskId);
        break;
      case WorkerEventType.progress:
        onProgress?.call(event.taskId, event.remaining ?? Duration.zero);
        break;
      case WorkerEventType.completed:
        onCompleted?.call(event.taskId, event.fromUi);
        break;
      case WorkerEventType.expired:
        onExpired?.call(event.taskId);
        break;
      case WorkerEventType.cancelled:
        onCancelled?.call(event.taskId, event.fromUi);
        break;
    }
  }
}
