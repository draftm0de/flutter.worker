import 'package:draftmode_ui/components.dart';
import 'package:draftmode_worker/event.dart';
import 'package:draftmode_worker_example/events/queued.dart';
import 'package:draftmode_worker_example/screen/home.dart';
import 'package:flutter/cupertino.dart';

class App extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const App({
    super.key,
    required this.navigatorKey,
  });

  Future<bool> _confirmEvent(ExampleQueueEvent event, Duration? autoConfirm) async {
    final result = await const DraftModeUIShowDialog().show(
      title: 'Queued Event',
      message: 'Event ${event.id} consumed.',
      confirmLabel: 'OK',
      cancelLabel: 'Later',
      autoConfirm: autoConfirm
    );
    if (result == true) {
      await _executeEvent(event);
    } else {
      debugPrint("execute Event denied");
    }
    return true;
  }

  Future<bool> _executeEvent(ExampleQueueEvent event) async {
    debugPrint("execute event");
    return true;
  }

  Future<bool> _handleEvent(DraftModeEventMessage message) {
    final event = message.event;
    if (event is ExampleQueueEvent) {
      debugPrint(
        'Queue event ${event.id} (${message.state}) created at '
            '${message.createdAt.toIso8601String()}',
      );
      if (message.autoConfirm != null) {
        switch (message.state) {
          case DraftModeEventMessageState.expired:
          case DraftModeEventMessageState.completed:
            return _executeEvent(event);
          case DraftModeEventMessageState.pending:
            return _confirmEvent(event, message.autoConfirm);
          default:
            break;
        }
        debugPrint(
            "Queue Event with autoConfirm state: ${message.state}");
        return Future.value(true);
      } else {
        return _confirmEvent(event, null);
      }
    }
    debugPrint('Unhandled DraftMode event: $event');
    return Future.value(false);
  }

  @override
  Widget build(BuildContext context) {
    return DraftModeEventWatcher(
      onEvent: _handleEvent,
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        home: const HomeScreen(),
      ),
    );
  }
}
