import 'package:draftmode_ui/components.dart';
import 'package:draftmode_worker/worker.dart';
import 'package:draftmode_worker_example/screen/home.dart';
import 'package:flutter/cupertino.dart';

class App extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const App({
    super.key,
    required this.navigatorKey,
  });

  Future<void> _handleActiveWorker(
      Map<String, dynamic> worker,
      ) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      return;
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
  }

  @override
  Widget build(BuildContext context) {
    return DraftModeWorkerWatcher(
      onActiveWorker: _handleActiveWorker,
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        home: const HomeScreen(),
      )
    );
  }
}
