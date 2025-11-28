import 'package:draftmode_ui/components/dialog.dart';
import 'package:draftmode_worker/event.dart';
import 'package:flutter/cupertino.dart';

import 'event.dart';

class ExampleQueueHandler {

  Future<bool> handleEvent(DraftModeEventMessage message) {
    final event = message.event;
    if (event is ExampleQueueEvent) {
      debugPrint(
        'Queue event ${event.id} (${message.state}) created at '
            '${message.createdAt.toIso8601String()}',
      );
      if (message.autoConfirm != null) {
        switch (message.state) {
          case DraftModeEventMessageState.expired:
          case DraftModeEventMessageState.completed:
            return executeEvent(event);
          case DraftModeEventMessageState.pending:
            return confirmEvent(event, message.autoConfirm);
          default:
            break;
        }
        debugPrint(
            "Queue Event with autoConfirm state: ${message.state}");
        return Future.value(true);
      } else {
        return confirmEvent(event, null);
      }
    }
    debugPrint('Unhandled DraftMode event: $event');
    return Future.value(false);
  }


  Future<bool> confirmEvent(ExampleQueueEvent event, Duration? autoConfirm) async {
    final result = await const DraftModeUIShowDialog().show(
        title: 'Queued Event',
        message: 'Event ${event.id} consumed.',
        confirmLabel: 'OK',
        cancelLabel: 'Later',
        autoConfirm: autoConfirm
    );
    if (result == true) {
      await executeEvent(event);
    } else {
      debugPrint("execute Event denied");
    }
    return true;
  }

  Future<bool> executeEvent(ExampleQueueEvent event) async {
    debugPrint("execute event");
    return true;
  }

}