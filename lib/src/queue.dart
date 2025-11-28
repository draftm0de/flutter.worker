import 'dart:async';
import 'package:flutter/widgets.dart';

import 'message.dart';
import 'worker.dart';

/// Event queue that defers delivery while the app is backgrounded and flushes
/// pending items as soon as we return to the foreground.
class DraftModeEventQueue with WidgetsBindingObserver {
  static const Object _workerToken = Object();

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
  final List<DraftModeEventMessage> _workerQueue = <DraftModeEventMessage>[];
  DraftModeEventMessage? _workerActive;

  // Fast lookup so worker callbacks can update queue metadata.
  final Map<String, DraftModeEventMessage> _workerById =
      <String, DraftModeEventMessage>{};

  Stream<DraftModeEventMessage> get stream => _controller.stream;

  /// Call this from your event producer (background/foreground).
  ///
  /// Specify [autoConfirm] to offload delivery to the iOS worker—useful when
  /// the app might be backgrounded for an extended period. The message will be
  /// surfaced to [DraftModeEventWatcher] only after the worker fires (e.g.
  /// expired/completed). Ensure your app calls `DraftModeWorker.init` so the
  /// worker callbacks are wired up.
  void push<T extends Object?>(T event, {Duration? autoConfirm}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final message = DraftModeEventMessage<T>(id, event, autoConfirm: autoConfirm);
    _pending.add(message);
    if (message.managedByWorker && autoConfirm != null) {
      message.ready = true; // surface pending state immediately
      _workerQueue.add(message);
      _workerById[id] = message;
      _startNextWorker();
    }
    if (_isForeground) {
      _dispatch();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      _waitingForResume = false;
      _dispatch();
    }
  }

  /// Surfaces the next ready event to listeners when foregrounded.
  void _dispatch() {
    if (!_isForeground || _active != null || _waitingForResume) {
      return;
    }
    final index = _pending.indexWhere((message) => message.ready);
    if (index == -1) return;
    final message = _pending[index];
    if (!message.managedByWorker &&
        message.state == DraftModeEventMessageState.pending) {
      message.state = DraftModeEventMessageState.completed;
    }
    _active = message;
    _debugDispatched.add(message.id);
    _controller.add(message);
  }

  /// Marks the [message] as handled (remove) or pending (await resume).
  void resolve(
    DraftModeEventMessage message, {
    required bool handled,
  }) {
    final active = _active;
    final index = _pending.indexWhere((element) => element.id == message.id);
    final bool isPendingWorker =
        message.managedByWorker &&
        message.state == DraftModeEventMessageState.pending;
    final bool shouldRemove = handled && !isPendingWorker;
    final bool shouldPause = !handled && !isPendingWorker;

    if (active != null && active.id == message.id) {
      if (shouldRemove) {
        if (index != -1) {
          _pending.removeAt(index);
        }
      } else if (shouldPause) {
        _waitingForResume = true;
      } else if (isPendingWorker) {
        message.ready = false; // Wait for worker completion before replaying.
      }
      _active = null;
    } else if (shouldRemove && index != -1) {
      _pending.removeAt(index);
    }

    if (shouldRemove) {
      _workerById.remove(message.id);
      if (_workerActive?.id == message.id) {
        _workerActive = null;
        _startNextWorker();
      }
    }

    if (_isForeground) {
      _dispatch();
    }
  }

  @visibleForTesting
  void debugReset() {
    _pending.clear();
    _active = null;
    _waitingForResume = false;
    _workerQueue.clear();
    _workerActive = null;
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

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
  }

  /// Runs the iOS worker for the next queued auto-confirm event.
  void _startNextWorker() {
    if (_workerActive != null) {
      return;
    }
    while (_workerQueue.isNotEmpty) {
      final candidate = _workerQueue.removeAt(0);
      if (!_pending.contains(candidate)) {
        _workerById.remove(candidate.id);
        continue;
      }
      final duration = candidate.autoConfirm;
      if (duration == null) {
        continue;
      }
      _workerActive = candidate;
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
    _finalizeWorker(eventId);
  }

  void _handleWorkerExpired(String eventId) {
    final message = _workerById[eventId];
    if (message == null) return;
    message.state = DraftModeEventMessageState.expired;
    message.ready = true;
    _finalizeWorker(eventId);
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
    if (_workerActive?.id == eventId) {
      _workerActive = null;
      _startNextWorker();
    }
    if (_isForeground) {
      _dispatch();
    }
  }
}
