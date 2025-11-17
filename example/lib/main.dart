import 'dart:async';

import 'package:draftmode_ui/components.dart';
import 'package:draftmode_ui/pages.dart';
import 'package:draftmode_worker/worker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the worker once globally
  DraftModeWorker.init(
    onStarted: (id) {
      DraftModeWorkerEvents.dispatch(WorkerEvent.started(id));
      debugPrint('🟢 Worker $id started');
    },
    onProgress: (id, remaining) {
      DraftModeWorkerEvents.dispatch(WorkerEvent.progress(id, remaining));
      debugPrint('⏳ Worker $id remaining: ${remaining.inSeconds}s');
    },
    onCompleted: (id, fromUi) {
      DraftModeWorkerEvents.dispatch(
        WorkerEvent.completed(id, fromUi: fromUi),
      );
      final origin = fromUi ? 'UI' : 'automatic';
      debugPrint('✅ Worker $id completed via $origin');
    },
    onExpired: (id) {
      DraftModeWorkerEvents.dispatch(WorkerEvent.expired(id));
      debugPrint('⚠️ Worker $id expired (iOS cut off early)');
    },
    onCancelled: (id, fromUi) {
      DraftModeWorkerEvents.dispatch(
        WorkerEvent.cancelled(id, fromUi: fromUi),
      );
      final origin = fromUi ? 'UI' : 'automatic';
      debugPrint('🛑 Worker $id cancelled via $origin');
    },
  );

  runApp(TimedWorkerExampleApp(navigatorKey: GlobalKey<NavigatorState>()));
}

class TimedWorkerExampleApp extends StatelessWidget {
  const TimedWorkerExampleApp({
    super.key,
    required this.navigatorKey,
  });

  final GlobalKey<NavigatorState> navigatorKey;

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
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: DraftModeWorkerWatcher(
        onActiveWorker: _handleActiveWorker,
        child: const TimedWorkerDemo(),
      ),
    );
  }
}

class TimedWorkerDemo extends StatefulWidget {
  const TimedWorkerDemo({super.key});

  @override
  State<TimedWorkerDemo> createState() => _TimedWorkerDemoState();
}

class _TimedWorkerDemoState extends State<TimedWorkerDemo> {
  bool isRunning = false;
  Duration? remaining;
  String? taskId;
  final TextEditingController _secondsController = TextEditingController(
    text: '20',
  );
  String? _inputError;
  StreamSubscription<WorkerEvent>? _workerEventsSub;
  String? _completionMessage;

  @override
  void initState() {
    super.initState();
    _workerEventsSub = DraftModeWorkerEvents.stream.listen(_handleWorkerEvent);
    _attachWorker();
  }

  @override
  void dispose() {
    _workerEventsSub?.cancel();
    _secondsController.dispose();
    super.dispose();
  }

  void _handleWorkerEvent(WorkerEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event.type) {
        case WorkerEventType.started:
          isRunning = true;
          taskId = event.taskId;
          _completionMessage = null;
          break;
        case WorkerEventType.progress:
          taskId = event.taskId;
          remaining = event.remaining;
          _completionMessage = null;
          break;
        case WorkerEventType.completed:
          if (taskId == event.taskId) {
            isRunning = false;
          }
          remaining = Duration.zero;
          _completionMessage =
              'completed at ${_formatTimestamp(DateTime.now())}';
          break;
        case WorkerEventType.expired:
          if (taskId == event.taskId) {
            isRunning = false;
          }
          remaining = event.remaining;
          _completionMessage = null;
          break;
        case WorkerEventType.cancelled:
          if (taskId == event.taskId) {
            isRunning = false;
          }
          remaining = Duration.zero;
          _completionMessage = null;
          break;
      }
    });
  }

  Future<void> _attachWorker() async {
    final status = await DraftModeWorker.status();
    if (status['isRunning'] == true) {
      setState(() {
        isRunning = true;
        remaining = Duration(milliseconds: status['remainingMs'] as int);
        taskId = status['taskId']?.toString();
        _completionMessage = null;
      });
    }
  }

  Future<void> _startWorker() async {
    final seconds = int.tryParse(_secondsController.text);
    if (seconds == null || seconds <= 0) {
      setState(() {
        _inputError = 'Enter seconds greater than 0';
      });
      return;
    }

    setState(() {
      _inputError = null;
    });

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await DraftModeWorker.start(
      taskId: id,
      duration: Duration(seconds: seconds),
    );
    setState(() {
      isRunning = true;
      taskId = id;
      remaining = Duration(seconds: seconds);
      _completionMessage = null;
    });
  }

  Future<void> _cancelWorker() async {
    await DraftModeWorker.cancel();
    setState(() {
      isRunning = false;
      remaining = null;
      taskId = null;
      _completionMessage = null;
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(DateTime dateTime) {
    return '${_twoDigits(dateTime.hour)}:'
        '${_twoDigits(dateTime.minute)}:'
        '${_twoDigits(dateTime.second)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final remText = _formatDuration(remaining ?? Duration.zero);
    final isCompleted = _completionMessage != null;
    final statusText = _completionMessage ?? 'Remaining: $remText';
    final Color statusColor = isCompleted
        ? CupertinoColors.activeGreen
        : CupertinoColors.label;

    return DraftModeUIPageExample(
      title: 'Timed Worker iOS Demo',
      children: [
        Text('Task ID: ${taskId ?? "-"}', style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        Text(
          statusText,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey, width: 0.8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Worker duration (seconds)',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _secondsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                placeholder: 'e.g. 20',
                enabled: !isRunning,
                style: const TextStyle(fontSize: 20),
              ),
              if (_inputError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _inputError!,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: isRunning ? null : _startWorker,
              child: const Text('Start Worker'),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              onPressed: isRunning ? _cancelWorker : null,
              child: const Text('Cancel Worker'),
            ),
          ),
        ),
      ],
    );
  }
}
