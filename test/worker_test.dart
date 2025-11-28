import 'dart:async';

import 'package:draftmode_worker/event.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('timed_worker_ios/channel');

Future<void> _sendWorkerMessage(String method, Map<String, Object?> args) async {
  final codec = const StandardMethodCodec();
  final data = codec.encodeMethodCall(MethodCall(method, args));
  final completer = Completer<void>();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    _channel.name,
    data,
    (_) => completer.complete(),
  );
  await completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final recordedCalls = <MethodCall>[];

  setUp(() {
    recordedCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          recordedCalls.add(call);
          if (call.method == 'status') {
            return {'isRunning': true, 'remainingMs': 1500, 'taskId': 'abc'};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('start forwards duration and task id over MethodChannel', () async {
    await DraftModeWorker.start(
      taskId: 'job-1',
      duration: const Duration(seconds: 2),
    );

    expect(recordedCalls, hasLength(1));
    expect(recordedCalls.single.method, 'start');
    expect(recordedCalls.single.arguments, {
      'taskId': 'job-1',
      'durationMs': 2000,
    });
  });

  test('cancel invokes cancel method with flag', () async {
    await DraftModeWorker.cancel();

    expect(recordedCalls.single.method, 'cancel');
    expect(recordedCalls.single.arguments, {'fromUi': false});
  });

  test('completed notifies native side with flag', () async {
    await DraftModeWorker.completed(fromUi: true);

    expect(recordedCalls.single.method, 'completed');
    expect(recordedCalls.single.arguments, {'fromUi': true});
  });

  test('status returns mapped response', () async {
    final res = await DraftModeWorker.status();

    expect(res['isRunning'], true);
    expect(res['remainingMs'], 1500);
    expect(res['taskId'], 'abc');
  });

  test('init wires callbacks from native side', () async {
    String? started;
    Duration? remaining;
    bool completed = false;
    bool completedFromUi = false;
    bool expired = false;
    bool cancelled = false;
    bool cancelledFromUi = false;

    DraftModeWorker.init(
      onStarted: (id) => started = id,
      onProgress: (id, duration) => remaining = duration,
      onCompleted: (id, fromUi) {
        completed = true;
        completedFromUi = fromUi;
      },
      onExpired: (id) => expired = true,
      onCancelled: (id, fromUi) {
        cancelled = true;
        cancelledFromUi = fromUi;
      },
    );

    await _sendWorkerMessage('worker_started', {'taskId': 'job-42'});
    await _sendWorkerMessage(
      'worker_progress',
      {'taskId': 'job-42', 'remainingMs': 750},
    );
    await _sendWorkerMessage(
      'worker_completed',
      {'taskId': 'job-42', 'fromUi': true},
    );
    await _sendWorkerMessage('worker_expired', {'taskId': 'job-42'});
    await _sendWorkerMessage(
      'worker_cancelled',
      {'taskId': 'job-42', 'fromUi': false},
    );

    expect(started, 'job-42');
    expect(remaining, const Duration(milliseconds: 750));
    expect(completed, isTrue);
    expect(completedFromUi, isTrue);
    expect(expired, isTrue);
    expect(cancelled, isTrue);
    expect(cancelledFromUi, isFalse);
  });

  test('queue bootstrap wires worker events to stream and callback', () async {
    DraftModeEventQueue.shared.debugReset();
    DraftModeEventQueue.debugResetBootstrap();

    final workerEvents = <WorkerEvent>[];
    final sub = DraftModeWorkerEvents.stream.listen(workerEvents.add);

    final lifecycleEvents = <WorkerEvent>[];
    final callbackEvents = <DraftModeEventMessage>[];
    DraftModeEventQueue.init(
      onWorkerLifecycle: lifecycleEvents.add,
      onEvent: (message) {
        callbackEvents.add(message);
        return true;
      },
    );

    DraftModeEventQueue.shared.push('bg-expired', autoConfirm: const Duration(seconds: 5));
    DraftModeEventQueue.shared.push('bg-completed', autoConfirm: const Duration(seconds: 5));
    final autoMessages = DraftModeEventQueue.shared.debugPendingMessages
        .where((message) => message.autoConfirm != null)
        .toList();
    final expiredId = autoMessages[0].id;
    final completedId = autoMessages[1].id;

    DraftModeEventQueue.shared
        .didChangeAppLifecycleState(AppLifecycleState.paused);

    await _sendWorkerMessage('worker_expired', {'taskId': expiredId});
    await _sendWorkerMessage(
      'worker_completed',
      {'taskId': completedId, 'fromUi': true},
    );

    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(workerEvents.map((e) => e.type), [
      WorkerEventType.expired,
      WorkerEventType.completed,
    ]);
    expect(workerEvents.last.fromUi, isTrue);
    expect(lifecycleEvents.map((e) => e.type), [
      WorkerEventType.expired,
      WorkerEventType.completed,
    ]);
    expect(callbackEvents.length, 2);
    expect(callbackEvents.first.state, DraftModeEventMessageState.expired);

    DraftModeEventQueue.shared
        .didChangeAppLifecycleState(AppLifecycleState.resumed);
  });
}
