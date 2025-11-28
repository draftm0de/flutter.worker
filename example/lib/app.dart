import 'package:draftmode_worker/event.dart';
import 'package:flutter/cupertino.dart';

import 'queue/handler.dart';
import 'screen/home.dart';

class App extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final ExampleQueueHandler queueHandler;

  const App({
    super.key,
    required this.navigatorKey,
    required this.queueHandler,
  });

  @override
  Widget build(BuildContext context) {
    return DraftModeEventWatcher(
      onEvent: queueHandler.handleEvent,
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        home: const HomeScreen(),
      ),
    );
  }
}
