import 'dart:async';
import 'package:draftmode_ui/context.dart';
import 'package:draftmode_worker/event.dart';
import 'package:flutter/cupertino.dart';

import 'app.dart';
import 'queue/handler.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
final ExampleQueueHandler _queueHandler = ExampleQueueHandler();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DraftModeEventQueue.bootstrap(onWorkerMessage: _queueHandler.handleEvent);
  DraftModeUIContext.init(navigatorKey: _navigatorKey);
  runApp(App(
    navigatorKey: _navigatorKey,
    queueHandler: _queueHandler,
  ));
}
