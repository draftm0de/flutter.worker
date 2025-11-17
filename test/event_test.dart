import 'package:draftmode_worker/worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DraftModeWorkerEvents broadcasts dispatched events', () async {
    final received = <WorkerEvent>[];
    final sub = DraftModeWorkerEvents.stream.listen(received.add);

    DraftModeWorkerEvents.dispatch(WorkerEvent.started('a'));
    DraftModeWorkerEvents.dispatch(
      WorkerEvent.progress('a', const Duration(seconds: 5)),
    );
    DraftModeWorkerEvents.dispatch(WorkerEvent.completed('a', fromUi: true));
    DraftModeWorkerEvents.dispatch(WorkerEvent.expired('a'));
    DraftModeWorkerEvents.dispatch(WorkerEvent.cancelled('a', fromUi: false));

    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(received.length, 5);
    expect(received[0].type, WorkerEventType.started);
    expect(received[1].remaining, const Duration(seconds: 5));
    expect(received[2].type, WorkerEventType.completed);
    expect(received[2].fromUi, isTrue);
    expect(received[3].type, WorkerEventType.expired);
    expect(received[4].type, WorkerEventType.cancelled);
  });
}
