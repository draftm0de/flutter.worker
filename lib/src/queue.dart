import 'dart:async';
import 'package:flutter/widgets.dart';

import 'message.dart';
import 'worker.dart';

/// Event queue that defers delivery while the app is backgrounded and flushes
/// pending items as soon as we return to the foreground.
class DraftModeEventQueue with WidgetsBindingObserver {
  static const Object _workerToken = Object();
  static bool _workerBridgeInitialized = false;
  static FutureOr<bool> Function(DraftModeEventMessage message)?
      _workerMessageHandler;
  static void Function(WorkerEvent event)? _workerLifecycleListener;

  /// Configures the worker bridge once so iOS lifecycle events propagate to
  /// the queue/watchers automatically. Call this during app bootstrap (e.g. in
  /// `main`) so background completions flow without extra wiring.
  static void init({
    FutureOr<bool> Function(DraftModeEventMessage message)? onEvent,
    void Function(WorkerEvent event)? onWorkerLifecycle,
  }) {
    if (onEvent != null) {
      _workerMessageHandler = onEvent;
    }
    if (onWorkerLifecycle != null) {
      _workerLifecycleListener = onWorkerLifecycle;
    }
    if (_workerBridgeInitialized) return;
    _workerBridgeInitialized = true;

    void dispatch(WorkerEvent event) {
      DraftModeWorkerEvents.dispatch(event);
      _workerLifecycleListener?.call(event);
    }

    DraftModeWorker.init(
      onStarted: (id) => dispatch(WorkerEvent.started(id)),
      onProgress: (id, remaining) =>
          dispatch(WorkerEvent.progress(id, remaining)),
      onCompleted: (id, fromUi) =>
          dispatch(WorkerEvent.completed(id, fromUi: fromUi)),
      onExpired: (id) => dispatch(WorkerEvent.expired(id)),
      onCancelled: (id, fromUi) =>
          dispatch(WorkerEvent.cancelled(id, fromUi: fromUi)),
    );
  }

  DraftModeEventQueue._internal() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    final lifecycle = binding.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;

    DraftModeEventWorker.init(
      token: _workerToken,
      onStarted: _handleWorkerStarted,
      onProgress: _handleWorkerProgress,
      onCompleted: _handleWorkerCompleted,
      onExpired: _handleWorkerExpired,
      onCancelled: _handleWorkerCancelled,
    );
  }

  static final DraftModeEventQueue shared = DraftModeEventQueue._internal();

  // Broadcast stream consumed by the watcher so UI stays in sync with queue.
  final _controller = StreamController<DraftModeEventMessage>.broadcast();

  // Pending events waiting for either confirmation or an app resume.
  final List<DraftModeEventMessage> _pending = <DraftModeEventMessage>[];

  // Helpful breadcrumb when tests want to assert dispatch order.
  final List<String> _debugDispatched = <String>[];

  // Currently surfaced message (only one at a time by design).
  DraftModeEventMessage? _active;
  bool _isForeground = false;
  bool _waitingForResume = false;

  // FIFO of events waiting for the timed worker to auto-confirm.
  final List<DraftModeEventMessage> _enqueuedEvents = <DraftModeEventMessage>[];
  DraftModeEventMessage? _enqueudEvent;

  // Fast lookup so worker callbacks can update queue metadata.
  final Map<String, DraftModeEventMessage> _workerById =
      <String, DraftModeEventMessage>{};

  Stream<DraftModeEventMessage> get stream => _controller.stream;

  /// Call this from your event producer (background/foreground).
  ///
  /// Specify [autoConfirm] to offload delivery to the iOS worker—useful when
  /// the app might be backgrounded for an extended period. The message will be
  /// surfaced to [DraftModeEventWatcher] only after the worker fires (e.g.
  /// expired/completed). Ensure your app calls `DraftModeEventQueue.bootstrap`
  /// so the worker callbacks are wired up.
  void push<T extends Object?>(T event, {Duration? autoConfirm}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    // create new message
    // : default.state = pending
    final message = DraftModeEventMessage<T>(id, event, autoConfirm: autoConfirm);

    // add message to List<DraftModeEventMessage>
    debugPrint("queue:push: queue-$id pushed added to List<_pending>");
    _pending.add(message);

    // handle message for background
    if (message.managedByWorker) {
      message.ready = true; // surface pending state immediately
      debugPrint("queue:push: queue-$id pushed to List<_enqueuedEvents>");
      _enqueuedEvents.add(message);
      debugPrint("queue:push: queue-$id pushed to _workerById");
      _workerById[id] = message;
      _startEnqueuedEvents();
    }

    if (_isForeground) {
      _dispatchNextEvent();
    }
  }

  /// appState changes background - foreground or foreground - background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    bool stateIsForeground = state == AppLifecycleState.resumed;
    if (stateIsForeground == _isForeground) return;
    _isForeground = stateIsForeground;
    String switchTo = _isForeground ? "Foreground" : "Background";
    debugPrint("queue:didChangeAppLifecycleState changed to: $switchTo");

    if (_isForeground) {
      _waitingForResume = false;
      _dispatchNextEvent();
    }
  }

  /// Surfaces the next ready event to listeners when foregrounded.
  void _dispatchNextEvent() {
    if (!_isForeground || _active != null || _waitingForResume) {
      return;
    }

    // fetch next (!autoConfirmed) message by state.ready
    // messages with autoConfirm are in default: !read
    // messages without autoConfirm are in default: ready
    final index = _pending.indexWhere((message) => message.ready);

    // none fetch, return
    if (index == -1)  {
      debugPrint("queue:_dispatchNextEvent, no message enqueued");
      return;
    }

    // get related message
    final message = _pending[index];

    // for !timedMessages, change state to completed (default state = pending)
    if (!message.managedByWorker &&
        message.state == DraftModeEventMessageState.pending) {
      message.state = DraftModeEventMessageState.completed;
    }

    // assign _active message
    _active = message;
    _debugDispatched.add(message.id);

    // attach those message to streamController
    // triggers the watcher.event
    debugPrint("queue:_dispatchNextEvent, queued-${message.id} pushed to streamController");
    _controller.add(message);
  }

  /// Marks the [message] as handled (remove) or pending (await resume).
  void resolve(
    DraftModeEventMessage message, {
    required bool acknowledge,
  }) {
    debugPrint("queue:resolve, queued-${message.id}, acknowledge: $acknowledge");
    final active = _active;
    final bool hasActive = active != null;

    // get message from _pending List
    final index = _pending.indexWhere((element) => element.id == message.id);
    final bool hasIndex = index != -1;

    debugPrint("queue:resolve, queued-${message.id}, managedByWorker: ${message.managedByWorker}, state: ${message.state}");
    final bool isPendingWorker =
        message.managedByWorker &&
        message.state == DraftModeEventMessageState.pending;
    debugPrint("queue:resolve, queued-${message.id}, isPendingWorker: $isPendingWorker");

    final bool shouldRemove = acknowledge && !isPendingWorker;
    final bool shouldPause = !acknowledge && !isPendingWorker;
    debugPrint("queue:resolve, queued-${message.id}, shouldRemove: $shouldRemove, shouldPause: $shouldPause, hasActive: $hasActive (${active?.id})");

    if (hasActive && active.id == message.id) {
      if (shouldRemove) {
        if (hasIndex) {
          debugPrint("queue:resolve, queued-${message.id} > remove from _pending");
          _pending.removeAt(index);
        }
      // acknowledge=false + not pendingWorker
      } else if (shouldPause) {
        _waitingForResume = true;
      } else if (isPendingWorker) {
        message.ready = false; // Wait for worker completion before replaying.
      }
      _active = null;
    } else if (shouldRemove && hasIndex) {
      debugPrint("queue:resolve, queued-${message.id} > remove from _pending");
      _pending.removeAt(index);
    }

    if (shouldRemove) {
      debugPrint("queue:resolve, queued-${message.id} > remove from _workerById");
      _workerById.remove(message.id);
      if (_enqueudEvent?.id == message.id) {
        _enqueudEvent = null;
        _startEnqueuedEvents();
      }
    }

    if (_isForeground) {
      // continue with dispatchingEvents
      _dispatchNextEvent();
    }
  }

  @visibleForTesting
  void debugReset() {
    _pending.clear();
    _active = null;
    _waitingForResume = false;
    _enqueuedEvents.clear();
    _enqueudEvent = null;
    _workerById.clear();
    _debugDispatched.clear();
  }

  @visibleForTesting
  DraftModeEventMessage? debugMessageById(String id) {
    try {
      return _pending.firstWhere((message) => message.id == id);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  bool get debugIsForeground => _isForeground;

  @visibleForTesting
  List<String> get debugDeliveredIds => List<String>.unmodifiable(_debugDispatched);

  @visibleForTesting
  List<DraftModeEventMessage> get debugPendingMessages =>
      List<DraftModeEventMessage>.unmodifiable(_pending);

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
  }

  @visibleForTesting
  static void debugResetBootstrap() {
    _workerBridgeInitialized = false;
    _workerMessageHandler = null;
    _workerLifecycleListener = null;
  }

  /// Runs the iOS worker for the next queued auto-confirm event.
  void _startEnqueuedEvents() {
    if (_enqueudEvent != null) {
      return;
    }
    while (_enqueuedEvents.isNotEmpty) {
      final candidate = _enqueuedEvents.removeAt(0);
      debugPrint("queue:_startEnqueuedEvents: use next queued-${candidate.id}");
      if (!_pending.contains(candidate)) {
        debugPrint("queue:_startEnqueuedEvents: event not in List<_pending> => continue and remove from _workerById");
        _workerById.remove(candidate.id);
        continue;
      }
      final duration = candidate.autoConfirm;
      if (duration == null) {
        debugPrint("queue:_startEnqueuedEvents: event has no autoConfirm => continue");
        continue;
      }

      // set _enqueudEvent = candidate
      _enqueudEvent = candidate;

      debugPrint("queue:_startEnqueuedEvents: trigger > DraftModeEventWorker.start");
      DraftModeEventWorker.start(
        eventId: candidate.id,
        duration: duration,
      );
      break;
    }
  }

  void _handleWorkerStarted(String eventId) {
    final message = _workerById[eventId];
    if (message == null) return;
    message.remaining = message.autoConfirm;
    message.state = DraftModeEventMessageState.pending;
  }

  void _handleWorkerProgress(String eventId, Duration remaining) {
    final message = _workerById[eventId];
    if (message == null) return;
    message.remaining = remaining;
  }

  void _handleWorkerCompleted(String eventId, bool fromUi) {
    final message = _workerById[eventId];
    if (message == null) return;
    message.state = DraftModeEventMessageState.completed;
    message.ready = true;
    final shouldHandleInBackground = !_isForeground;
    _finalizeWorker(eventId);
    if (shouldHandleInBackground) {
      _handleBackgroundWorkerMessage(message);
    }
  }

  void _handleWorkerExpired(String eventId) {
    final message = _workerById[eventId];
    if (message == null) return;
    message.state = DraftModeEventMessageState.expired;
    message.ready = true;
    final shouldHandleInBackground = !_isForeground;
    _finalizeWorker(eventId);
    if (shouldHandleInBackground) {
      _handleBackgroundWorkerMessage(message);
    }
  }

  void _handleWorkerCancelled(String eventId, bool fromUi) {
    final message = _workerById[eventId];
    if (message == null) return;
    message.state = DraftModeEventMessageState.cancelled;
    message.ready = true;
    _finalizeWorker(eventId);
  }

  /// Cleans up worker bookkeeping once iOS reports a terminal state.
  void _finalizeWorker(String eventId) {
    _workerById.remove(eventId);
    if (_enqueudEvent?.id == eventId) {
      _enqueudEvent = null;
      _startEnqueuedEvents();
    }
    if (_isForeground) {
      _dispatchNextEvent();
    }
  }

  void _handleBackgroundWorkerMessage(DraftModeEventMessage message) {
    final handler = _workerMessageHandler;
    if (handler == null) return;
    message.ready = false;
    Future<void>(() async {
      bool handled = false;
      try {
        handled = await Future<bool>.sync(() => handler(message));
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'draftmode_worker',
            context: ErrorDescription('while handling background event ${message.id}'),
          ),
        );
      }

      if (handled) {
        _removePendingMessage(message.id);
      } else {
        message.ready = true;
        if (_isForeground) {
          _dispatchNextEvent();
        }
      }
    });
  }

  void _removePendingMessage(String messageId) {
    final index = _pending.indexWhere((element) => element.id == messageId);
    if (index != -1) {
      _pending.removeAt(index);
    }
    if (_active?.id == messageId) {
      _active = null;
    }
  }
}
