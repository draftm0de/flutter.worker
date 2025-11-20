import 'dart:async';
import 'package:draftmode_ui/components.dart';
import 'package:draftmode_ui/pages.dart';
import 'package:draftmode_worker/worker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
        DraftModeUISection(
          header: "Worker",
          children: [
            DraftModeUIRow(
              Text('Task ID: ${taskId ?? "-"}', style: const TextStyle(fontSize: 16))
            ),
            DraftModeUIRow(
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                ),
                textAlign: TextAlign.center,
              )
            )
          ],
        ),
        DraftModeUISection(
          header: "Configuration",
          children: [
            DraftModeUIRow(CupertinoTextField(
              controller: _secondsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              placeholder: 'e.g. 20',
              enabled: !isRunning,
            ), label: "Delay (sec)"),
            if (_inputError != null) ...[
              DraftModeUIRow(Text(
                _inputError!,
                style: const TextStyle(color: CupertinoColors.systemRed),
              )),
            ]
          ]
        ),
        const SizedBox(height: 10),
        DraftModeUISection(
          transparent: true,
          children: [
            SizedBox(
              width: double.infinity,
              child: CupertinoButton.filled(
                onPressed: isRunning ? null : _startWorker,
                child: const Text('Start Worker'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                onPressed: isRunning ? _cancelWorker : null,
                child: const Text('Cancel Worker'),
              ),
            )
          ],
        ),
      ],
    );
  }
}