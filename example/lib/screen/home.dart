import 'dart:async';
import 'package:draftmode_ui/components.dart';
import 'package:draftmode_ui/pages.dart';
import 'package:draftmode_worker/event.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
//
import '../queue/event.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _secondsController = TextEditingController(
    text: '20',
  );
  final TextEditingController _autoConfirmController = TextEditingController(
    text: '20',
  );
  String? _inputError;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _secondsController.dispose();
    _autoConfirmController.dispose();
    super.dispose();
  }

  int _getStartDelay() {
    final seconds = int.tryParse(_secondsController.text);
    if (seconds == null || seconds <= 0) {
      throw 'Enter seconds greater than 0';
    }
    return seconds;
  }

  Future<void> _startEvent() async {
    final seconds = _getStartDelay();
    debugPrint("_startEvent: enqueued");

    unawaited(Future<void>(() async {
      await Future.delayed(Duration(seconds: seconds));
      final event = ExampleQueueEvent(
        id: 'queued-${DateTime.now().millisecondsSinceEpoch}',
      );
      debugPrint("home:_startEvent: > DraftModeEventQueue.shared.push");
      DraftModeEventQueue.shared.push(event);
    }));
  }

  Future<void> _startTimedEvent() async {
    final autoConfirm = int.tryParse(_autoConfirmController.text);
    if (autoConfirm == null || autoConfirm <= 0) {
      throw 'Enter autoConfirm greater than 0';
    }
    final seconds = _getStartDelay();

    debugPrint("home:_startTimedEvent: enqueued");

    unawaited(Future<void>(() async {
      await Future.delayed(Duration(seconds: seconds));
      final event = ExampleQueueEvent(
        id: 'queued-${DateTime.now().millisecondsSinceEpoch}',
      );
      debugPrint("home:_startTimedEvent: > DraftModeEventQueue.shared.push(+autoConfirm)");
      DraftModeEventQueue.shared.push(event, autoConfirm: Duration(seconds: autoConfirm));
    }));
  }

  @override
  Widget build(BuildContext context) {
    return DraftModeUIPageExample(
      title: 'Timed Worker iOS Demo',
      children: [
        DraftModeUISection(
          header: "Configuration",
          labelWidth: 130,
          children: [
            DraftModeUIRow(CupertinoTextField(
              controller: _secondsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              placeholder: 'e.g. 20',
            ), label: "Delay", expanded: Text('sec')),
            if (_inputError != null) ...[
              DraftModeUIRow(Text(
                _inputError!,
                style: const TextStyle(color: CupertinoColors.systemRed),
              )),
            ],
            DraftModeUIRow(CupertinoTextField(
              controller: _autoConfirmController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              placeholder: 'e.g. 20',
            ), label: "AutoConfirm", expanded: Text('sec')),
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
            DraftModeUIButton.text('Event (confirm, !autoConfirm)', onPressed: _startEvent),
            const SizedBox(height: 5),
            DraftModeUIButton.text('timedEvent (autoConfirm)', onPressed: _startTimedEvent),
          ],
        ),
      ],
    );
  }
}
