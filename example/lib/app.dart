import 'package:draftmode_worker/event.dart';
import 'package:flutter/cupertino.dart';
//
import 'queue/handler.dart';
import 'screen/home.dart';

class App extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const App({
    super.key,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return DraftModeEventWatcher(
      onEvent: ExampleQueueHandler().handleEvent,
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        home: const HomeScreen(),
      ),
    );
  }
}
