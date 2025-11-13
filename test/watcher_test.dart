import 'dart:async';

import 'package:draftmode_worker/worker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('timed_worker_ios/channel');
  Map<String, Object?> statusResponse = const {'isRunning': false};
  int cancelCalls = 0;

  setUp(() {
    statusResponse = const {'isRunning': false};
    cancelCalls = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'status') {
            return statusResponse;
          }
          if (call.method == 'cancel') {
            cancelCalls += 1;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpWatcher(
    WidgetTester tester, {
    Future<void> Function(String? taskId)? onSubmitNow,
  }) {
    return tester.pumpWidget(
      CupertinoApp(
        home: DraftModeWorkerWatcher(
          onSubmitNow: onSubmitNow,
          child: const Placeholder(),
        ),
      ),
    );
  }

  testWidgets('shows dialog when worker is active after cold start', (
    tester,
  ) async {
    statusResponse = const {
      'isRunning': true,
      'remainingMs': 1200,
      'taskId': 'demo',
    };

    await pumpWatcher(tester);
    await tester.pump();

    expect(find.text('Active Worker'), findsOneWidget);
    expect(find.textContaining('Task: demo'), findsOneWidget);

    await tester.tap(find.text('Leave running'));
    await tester.pumpAndSettle();
  });

  testWidgets('submit now cancels worker and notifies callback', (
    tester,
  ) async {
    final submitted = <String?>[];
    final completer = Completer<void>();
    statusResponse = const {
      'isRunning': true,
      'remainingMs': 500,
      'taskId': 'abc',
    };

    await pumpWatcher(
      tester,
      onSubmitNow: (taskId) async {
        submitted.add(taskId);
        completer.complete();
      },
    );
    await tester.pump();

    await tester.tap(find.text('Submit now'));
    await tester.pumpAndSettle();
    await completer.future;

    expect(cancelCalls, 1);
    expect(submitted, ['abc']);
  });

  testWidgets('resumed lifecycle triggers dialog', (tester) async {
    statusResponse = const {'isRunning': false};

    await pumpWatcher(tester);
    await tester.pump();
    expect(find.text('Active Worker'), findsNothing);

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

    expect(find.text('Active Worker'), findsOneWidget);
  });
}
