import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Discrete worker lifecycle notifications emitted by the iOS background task.
enum WorkerEventType { started, progress, completed, expired, cancelled }

/// Lightweight event payload that is broadcast to listeners inside the plugin
/// as well as any consuming apps.
class WorkerEvent {
  const WorkerEvent._(this.type, this.taskId, this.remaining, this.fromUi);

  factory WorkerEvent.started(String taskId) =>
      WorkerEvent._(WorkerEventType.started, taskId, null, false);

  factory WorkerEvent.progress(String taskId, Duration remaining) =>
      WorkerEvent._(WorkerEventType.progress, taskId, remaining, false);

  factory WorkerEvent.completed(String taskId, {bool fromUi = false}) =>
      WorkerEvent._(WorkerEventType.completed, taskId, Duration.zero, fromUi);

  factory WorkerEvent.expired(String taskId) =>
      WorkerEvent._(WorkerEventType.expired, taskId, Duration.zero, false);

  factory WorkerEvent.cancelled(String taskId, {bool fromUi = false}) =>
      WorkerEvent._(WorkerEventType.cancelled, taskId, Duration.zero, fromUi);

  final WorkerEventType type;
  final String taskId;
  final Duration? remaining;
  final bool fromUi;
}

/// Tiny event bus that exposes the worker lifecycle as a broadcast [Stream].
class DraftModeWorkerEvents {
  DraftModeWorkerEvents._(); // coverage:ignore-line

  static final StreamController<WorkerEvent> _controller =
      StreamController<WorkerEvent>.broadcast();

  static Stream<WorkerEvent> get stream => _controller.stream;

  static void dispatch(WorkerEvent event) {
    _controller.add(event);
  }
}

typedef WorkerStarted = void Function(String taskId);
typedef WorkerProgress = void Function(String taskId, Duration remaining);
typedef WorkerCompleted = void Function(String taskId, bool fromUi);
typedef WorkerExpired = void Function(String taskId);
typedef WorkerCancelled = void Function(String taskId, bool fromUi);

/// Public API that bridges the Flutter side to the iOS timed worker.
class DraftModeWorker {
  DraftModeWorker._(); // coverage:ignore-line
  static const _ch = MethodChannel('timed_worker_ios/channel');

  static WorkerStarted? _onStarted;
  static WorkerProgress? _onProgress;
  static WorkerCompleted? _onCompleted;
  static WorkerExpired? _onExpired;
  static WorkerCancelled? _onCancelled;

  static void init({
    WorkerStarted? onStarted,
    WorkerProgress? onProgress,
    WorkerCompleted? onCompleted,
    WorkerExpired? onExpired,
    WorkerCancelled? onCancelled,
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
          _onStarted?.call(m['taskId'] as String);
          break;
        case 'worker_progress':
          _onProgress?.call(
            m['taskId'] as String,
            Duration(milliseconds: (m['remainingMs'] as num).toInt()),
          );
          break;
        case 'worker_completed':
          _onCompleted?.call(
            m['taskId'] as String,
            (m['fromUi'] as bool?) ?? false,
          );
          break;
        case 'worker_cancelled':
          _onCancelled?.call(
            m['taskId'] as String,
            (m['fromUi'] as bool?) ?? false,
          );
          break;
        case 'worker_expired':
          _onExpired?.call(m['taskId'] as String);
          break;
      }
    });
  }

  static Future<void> start({
    required String taskId,
    required Duration duration,
  }) {
    return _ch.invokeMethod('start', {
      'taskId': taskId,
      'durationMs': duration.inMilliseconds,
    });
  }

  static Future<void> cancel({bool fromUi = false}) => _ch.invokeMethod(
        'cancel',
        {'fromUi': fromUi},
      );

  static Future<void> completed({bool fromUi = false}) => _ch.invokeMethod(
        'completed',
        {'fromUi': fromUi},
      );

  static Future<Map<String, dynamic>> status() async {
    final res = await _ch.invokeMethod('status');
    return Map<String, dynamic>.from(res as Map? ?? {});
  }
}

/// Signature used when the watcher detects an active worker.
typedef DraftModeWorkerWatcherCallback = FutureOr<void> Function(
  Map<String, dynamic> worker,
);

/// Monitors the worker state whenever the app resumes (or cold starts) and
/// invokes [onEvent] with the latest worker status when it is still running.
class DraftModeWorkerWatcher extends StatefulWidget {
  final Widget child;
  final DraftModeWorkerWatcherCallback onEvent;

  const DraftModeWorkerWatcher({
    super.key,
    required this.child,
    required this.onEvent,
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
        () => widget.onEvent(
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
    return widget.child;
  }
}

/// Public API that bridges the Flutter side to the iOS timed worker for
/// DraftMode event queue usage.
class DraftModeEventWorker {
  DraftModeEventWorker._(); // coverage:ignore-line

  static final Map<Object, _DraftModeEventWorkerCallbacks> _listeners =
      <Object, _DraftModeEventWorkerCallbacks>{};
  static final Object _defaultToken = Object();
  static StreamSubscription<WorkerEvent>? _sub;

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

  static Future<void> start({
    required String eventId,
    required Duration duration,
  }) {
    return DraftModeWorker.start(taskId: eventId, duration: duration);
  }

  static Future<void> cancel({bool fromUi = false}) =>
      DraftModeWorker.cancel(fromUi: fromUi);

  static Future<void> completed({bool fromUi = false}) =>
      DraftModeWorker.completed(fromUi: fromUi);

  static Future<Map<String, dynamic>> status() => DraftModeWorker.status();
}

typedef DraftModeEventWorkerStarted = void Function(String eventId);
typedef DraftModeEventWorkerProgress = void Function(
  String eventId,
  Duration remaining,
);
typedef DraftModeEventWorkerCompleted = void Function(
  String eventId,
  bool fromUi,
);
typedef DraftModeEventWorkerExpired = void Function(String eventId);
typedef DraftModeEventWorkerCancelled = void Function(
  String eventId,
  bool fromUi,
);

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
