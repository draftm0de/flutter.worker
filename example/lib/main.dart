import 'dart:async';
import 'package:draftmode_worker/worker.dart';
import 'package:flutter/cupertino.dart';
import 'app.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DraftModeWorker.init(
    onStarted: (id) {
      DraftModeWorkerEvents.dispatch(WorkerEvent.started(id));
      debugPrint('🟢 Worker $id started');
    },
    onProgress: (id, remaining) {
      DraftModeWorkerEvents.dispatch(WorkerEvent.progress(id, remaining));
      debugPrint('⏳ Worker $id remaining: ${remaining.inSeconds}s');
    },
    onCompleted: (id, fromUi) {
      DraftModeWorkerEvents.dispatch(
        WorkerEvent.completed(id, fromUi: fromUi),
      );
      final origin = fromUi ? 'UI' : 'automatic';
      debugPrint('✅ Worker $id completed via $origin');
    },
    onExpired: (id) {
      DraftModeWorkerEvents.dispatch(WorkerEvent.expired(id));
      debugPrint('⚠️ Worker $id expired (iOS cut off early)');
    },
    onCancelled: (id, fromUi) {
      DraftModeWorkerEvents.dispatch(
        WorkerEvent.cancelled(id, fromUi: fromUi),
      );
      final origin = fromUi ? 'UI' : 'automatic';
      debugPrint('🛑 Worker $id cancelled via $origin');
    },
  );
  runApp(App(navigatorKey: _navigatorKey));
}

