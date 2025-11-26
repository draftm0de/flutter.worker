import 'dart:async';
import 'package:flutter/widgets.dart';
import 'element.dart';

/// Event queue that defers delivery while the app is backgrounded and flushes
/// pending items as soon as we return to the foreground.
class DraftModeEventQueue with WidgetsBindingObserver {
  DraftModeEventQueue._internal() {
    final binding = WidgetsBinding.instance;
    binding.addObserver(this);
    final lifecycle = binding.lifecycleState;
    _isForeground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  static final DraftModeEventQueue shared = DraftModeEventQueue._internal();

  final _controller = StreamController<DraftModeEventElement>.broadcast();
  final List<DraftModeEventElement> _pending = [];
  bool _isForeground = false;

  Stream<DraftModeEventElement> get stream => _controller.stream;

  /// Call this from your event producer (background/foreground).
  void add<T extends Object?>(T event, {Duration? delay}) {
    final envelope = DraftModeEventElement(event, delay: delay);
    if (_isForeground) {
      _controller.add(envelope); // Deliver immediately while we have UI.
    } else {
      _pending.add(envelope); // Queue for later when we resume.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      _flushPending();
    }
  }

  void _flushPending() {
    if (_pending.isEmpty) return;
    for (final event in List<DraftModeEventElement>.from(_pending)) {
      _controller.add(event);
    }
    _pending.clear();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
  }
}
