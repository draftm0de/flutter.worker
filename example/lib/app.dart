import 'package:draftmode_ui/components.dart';
import 'package:draftmode_worker/event.dart';
import 'package:draftmode_worker/worker.dart';
import 'package:draftmode_worker_example/events/queued.dart';
import 'package:draftmode_worker_example/screen/home.dart';
import 'package:flutter/cupertino.dart';

class App extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const App({
    super.key,
    required this.navigatorKey,
  });

  Future<void> _handleActiveWorker(Map<String, dynamic> worker) async {
    DraftModeEventQueue.shared.add(
      ActiveWorkerEvent(Map<String, dynamic>.from(worker)),
    );
  }

  Future<bool> _showActiveWorkerDialog(Map<String, dynamic> worker) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      return false;
    }
    final remaining = Duration(
      milliseconds: (worker['remainingMs'] as num?)?.toInt() ?? 0,
    );
    final taskId = worker['taskId']?.toString();
    final confirm = await DraftModeUIDialog.show(
      context: context,
      title: 'Active Worker',
      message: 'Task: $taskId is still running. Submit now?',
      autoConfirm: remaining,
    );
    if (confirm == true) {
      await DraftModeWorker.completed(fromUi: true);
    } else if (confirm == false) {
      await DraftModeWorker.cancel(fromUi: true);
    }
    return true;
  }

  Future<bool> _showQueuedEventDialog(ExampleQueueEvent event) async {
    final result = await const DraftModeUIShowDialog().show(
      title: 'Queued Event',
      message: 'Event ${event.id} consumed.',
      confirmLabel: 'OK',
      cancelLabel: 'Later',
    );
    return result == true;
  }

  Future<bool> _handleDraftModeEvent(DraftModeEventElement element) {
    final event = element.event;
    if (event is ActiveWorkerEvent) {
      return _showActiveWorkerDialog(event.worker);
    }
    if (event is ExampleQueueEvent) {
      debugPrint('Queue event ${event.id} created at ${element.createdAt.toIso8601String()}');
      return _showQueuedEventDialog(event);
    }
    debugPrint('Unhandled DraftMode event: $event');
    return Future.value(false);
  }

  @override
  Widget build(BuildContext context) {
    return DraftModeEventWatcher(
      onEvent: _handleDraftModeEvent,
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        home: const HomeScreen(),
      ),
    );
  }
}
