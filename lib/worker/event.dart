import 'dart:async';

/// Discrete worker lifecycle notifications emitted by the iOS background task.
enum WorkerEventType { started, progress, completed, expired }

/// Lightweight event payload that is broadcast to listeners inside the plugin
/// as well as any consuming apps. Convenience factories keep call‑sites tidy
/// and ensure the `remaining` duration is only present when it is meaningful.
class WorkerEvent {
  const WorkerEvent._(this.type, this.taskId, this.remaining);

  /// Emitted when iOS tells us the worker began executing.
  factory WorkerEvent.started(String taskId) =>
      WorkerEvent._(WorkerEventType.started, taskId, null);

  /// Emitted periodically while the worker is alive with the remaining time
  /// reported by iOS.
  factory WorkerEvent.progress(String taskId, Duration remaining) =>
      WorkerEvent._(WorkerEventType.progress, taskId, remaining);

  /// Emitted once the worker completes successfully.
  factory WorkerEvent.completed(String taskId) =>
      WorkerEvent._(WorkerEventType.completed, taskId, Duration.zero);

  /// Emitted if iOS expires the worker early (e.g. background budget ended).
  factory WorkerEvent.expired(String taskId) =>
      WorkerEvent._(WorkerEventType.expired, taskId, Duration.zero);

  /// Type of lifecycle event that occurred.
  final WorkerEventType type;

  /// ID originally supplied by the app when the worker was created.
  final String taskId;

  /// Remaining runtime reported by iOS. Only set for `progress` events.
  final Duration? remaining;
}

/// Tiny event bus that exposes the worker lifecycle as a broadcast [Stream].
/// Apps can listen to it to keep UI (or other layers) in sync with iOS.
class DraftModeWorkerEvents {
  DraftModeWorkerEvents._(); // coverage:ignore-line

  static final StreamController<WorkerEvent> _controller =
      StreamController<WorkerEvent>.broadcast();

  /// Broadcast stream of worker events. Multiple listeners are supported.
  static Stream<WorkerEvent> get stream => _controller.stream;

  /// Pushes a new [WorkerEvent] into the stream.
  static void dispatch(WorkerEvent event) {
    _controller.add(event);
  }
}
