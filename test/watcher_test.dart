import 'package:draftmode_worker/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('timed_worker_ios/channel');
  Map<String, Object?> statusResponse = const {'isRunning': false};

  setUp(() {
    statusResponse = const {'isRunning': false};

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'status') {
            return statusResponse;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpWatcher(
    WidgetTester tester,
    DraftModeWorkerWatcherCallback onEvent,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: DraftModeWorkerWatcher(
          child: const Placeholder(),
          onEvent: onEvent,
        ),
      ),
    );
  }

  testWidgets('invokes callback with worker when active after cold start', (
    tester,
  ) async {
    statusResponse = const {
      'isRunning': true,
      'remainingMs': 1200,
      'taskId': 'demo',
    };

    Map<String, dynamic>? callbackWorker;
    int callbackCount = 0;
    await pumpWatcher(tester, (worker) {
      callbackWorker = worker;
      callbackCount += 1;
    });
    await tester.pump();

    expect(callbackCount, 1);
    expect(callbackWorker?['taskId'], 'demo');
  });

  testWidgets('resumed lifecycle triggers callback', (tester) async {
    statusResponse = const {'isRunning': false};

    int callbackCount = 0;
    await pumpWatcher(tester, (_) {
      callbackCount += 1;
    });
    await tester.pump();
    expect(callbackCount, 0);

    statusResponse = const {
      'isRunning': true,
      'remainingMs': 3000,
      'taskId': 'later',
    };

    final observer =
        tester.state(find.byType(DraftModeWorkerWatcher))
            as WidgetsBindingObserver;
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(callbackCount, 1);
  });

  testWidgets('does not trigger callback when no worker is running', (
    tester,
  ) async {
    statusResponse = const {'isRunning': false};
    int callbackCount = 0;
    await pumpWatcher(tester, (_) {
      callbackCount += 1;
    });
    await tester.pumpAndSettle();

    expect(callbackCount, 0);
  });
}
