import 'dart:async';

import 'package:async/async.dart';
import 'package:draftmode_worker/event.dart';
import 'package:draftmode_worker/worker.dart' show DraftModeWorkerEvents, WorkerEvent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DraftModeEventQueue.shared.debugReset();
  });

  Future<void> _pumpWatcher(
    WidgetTester tester,
    Future<bool> Function(DraftModeEventMessage element) onEvent,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: DraftModeEventWatcher(
          onEvent: onEvent,
          child: const Placeholder(),
        ),
      ),
    );
  }

  testWidgets('delivers events sequentially after acknowledgement', (
    tester,
  ) async {
    final delivered = <String>[];
    final completions = <Completer<bool>>[];

    await _pumpWatcher(tester, (element) async {
      delivered.add(element.event as String);
      final completer = Completer<bool>();
      completions.add(completer);
      return completer.future;
    });

    DraftModeEventQueue.shared.push('first');
    DraftModeEventQueue.shared.push('second');

    await tester.pump();
    expect(delivered, ['first']);

    // While the first event is unresolved, the second should not fire.
    await tester.pump();
    expect(delivered, ['first']);

    completions.removeAt(0).complete(true);
    await tester.pump();
    expect(delivered, ['first', 'second']);

    // Resolve the second event to clean up the listener.
    completions.removeAt(0).complete(true);
    await tester.pump();
  });

  testWidgets('replays pending events after lifecycle resume when deferred', (
    tester,
  ) async {
    final delivered = <String>[];
    final completions = <Completer<bool>>[];

    await _pumpWatcher(tester, (element) async {
      delivered.add(element.event as String);
      final completer = Completer<bool>();
      completions.add(completer);
      return completer.future;
    });

    DraftModeEventQueue.shared.push('confirm');
    await tester.pump();
    expect(delivered, ['confirm']);

    // Defer the event, which should pause further delivery.
    completions.removeAt(0).complete(false);
    await tester.pump();
    expect(delivered, ['confirm']);

    DraftModeEventQueue.shared.push('later');
    await tester.pump();
    expect(delivered, ['confirm']);

    // Simulate the app returning to the foreground to replay the pending event.
    DraftModeEventQueue.shared
        .didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(delivered, ['confirm', 'confirm']);

    // Handle the replayed event which should then allow the next event through.
    completions.removeAt(0).complete(true);
    await tester.pump();
    expect(delivered, ['confirm', 'confirm', 'later']);

    completions.removeAt(0).complete(true);
    await tester.pump();
  });

  testWidgets('autoConfirm messages wait for worker expiration', (tester) async {
    const channel = MethodChannel('timed_worker_ios/channel');
    MethodCall? startCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') {
        startCall = call;
      }
      return null;
    });

    final delivered = <DraftModeEventMessage>[];
    final streamQueue = StreamQueue<DraftModeEventMessage>(
      DraftModeEventQueue.shared.stream,
    );
    addTearDown(streamQueue.cancel);

    DraftModeEventQueue.shared.push('auto', autoConfirm: const Duration(seconds: 5));
    await tester.pump();
    expect(delivered, isEmpty);
    expect(DraftModeEventQueue.shared.debugIsForeground, isTrue);

    final rawArgs = startCall?.arguments as Map<Object?, Object?>?;
    expect(rawArgs, isNotNull);
    final args = Map<String, dynamic>.from(rawArgs!);
    final eventId = args['taskId'] as String;

    // Watcher should be notified immediately with a pending message.
    final pendingMessage = await streamQueue.next;
    expect(pendingMessage.state, DraftModeEventMessageState.pending);
    DraftModeEventQueue.shared.resolve(pendingMessage, handled: true);

    DraftModeWorkerEvents.dispatch(WorkerEvent.expired(eventId));
    await tester.pump();
    await tester.pump();

    final pending = DraftModeEventQueue.shared.debugMessageById(eventId);
    expect(pending?.ready, isTrue);

    expect(DraftModeEventQueue.shared.debugDeliveredIds, isNotEmpty);

    final message = await streamQueue.next;
    DraftModeEventQueue.shared.resolve(message, handled: true);
    delivered.add(message);

    expect(delivered, hasLength(1));
    expect(delivered.first.state, DraftModeEventMessageState.expired);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
