import 'dart:async';

import 'package:draftmode_worker/event.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('timed_worker_ios/channel');

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

    Future<void> send(String method, Map<String, Object?> args) async {
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

    await send('worker_started', {'taskId': 'job-42'});
    await send('worker_progress', {'taskId': 'job-42', 'remainingMs': 750});
    await send('worker_completed', {'taskId': 'job-42', 'fromUi': true});
    await send('worker_expired', {'taskId': 'job-42'});
    await send('worker_cancelled', {'taskId': 'job-42', 'fromUi': false});

    expect(started, 'job-42');
    expect(remaining, const Duration(milliseconds: 750));
    expect(completed, isTrue);
    expect(completedFromUi, isTrue);
    expect(expired, isTrue);
    expect(cancelled, isTrue);
    expect(cancelledFromUi, isFalse);
  });
}
