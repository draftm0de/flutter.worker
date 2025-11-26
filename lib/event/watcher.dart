import 'dart:async';
import 'package:flutter/widgets.dart';
import 'element.dart';
import 'queue.dart';

/// Hooks into the global [DraftModeEventQueue] and invokes the callbacks
/// associated with each event when they are finally delivered to the UI.
class DraftModeEventWatcher extends StatefulWidget {
  /// Wraps the portion of the UI that should stay mounted while the watcher is
  /// active. Usually this is the app's `home` widget or a shell around it.
  final Widget child;

  /// Handler invoked whenever the queue delivers an event to the UI.
  final Future<bool> Function(DraftModeEventElement element) onEvent;

  const DraftModeEventWatcher({
    super.key,
    required this.child,
    required this.onEvent,
  });

  @override
  State<DraftModeEventWatcher> createState() => _DraftModeEventWatcherState();
}

class _DraftModeEventWatcherState extends State<DraftModeEventWatcher> {
  StreamSubscription<DraftModeEventElement>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = DraftModeEventQueue.shared.stream.listen(_handleEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handleEvent(DraftModeEventElement envelope) async {
    try {
      await widget.onEvent(envelope);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'draftmode_worker',
          context: ErrorDescription(
            'while handling DraftMode event ${envelope.event.runtimeType}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: return child directly → context is always valid
    return widget.child;
  }
}
