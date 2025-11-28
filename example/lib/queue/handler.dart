import 'package:draftmode_ui/components/dialog.dart';
import 'package:draftmode_worker/event.dart';
import 'package:flutter/cupertino.dart';

import 'event.dart';

class ExampleQueueHandler {

  Future<bool> handleBackendEvent(DraftModeEventMessage message) async {
    final event = message.event;
    if (event is ExampleQueueEvent) {
      debugPrint('handleBackendEvent: ${event.id} (${message.state}) consuming');
    }
    bool acknowledge = true;
    debugPrint('handleBackendEvents: acknowledge: $acknowledge');
    return acknowledge;
  }

  Future<bool> handleForegroundEvent(DraftModeEventMessage message) async {
    final event = message.event;
    bool acknowledge = true;
    if (event is ExampleQueueEvent) {
      debugPrint('handleForegroundEvent: ${event.id} (${message.state}) consuming');
      if (message.autoConfirm != null) {
        debugPrint("handleForegroundEvent: event with autoConfirm");
        switch (message.state) {
          case DraftModeEventMessageState.expired:
          case DraftModeEventMessageState.completed:
            acknowledge = await executeEvent(event);
          break;
          case DraftModeEventMessageState.pending:
            acknowledge = await confirmEvent(event, null); //, message.autoConfirm);
          break;
          default:
            acknowledge = false;
            break;
        }
      } else {
        acknowledge = await confirmEvent(event, null);
      }
    } else {
      debugPrint('handleForegroundEvent: ${event.id} (${message.state}) unknown');
      acknowledge = false;
    }
    debugPrint('handleForegroundEvent: acknowledge: $acknowledge');
    return acknowledge;
  }


  Future<bool> confirmEvent(ExampleQueueEvent event, Duration? autoConfirm) async {
    final confirmed = await const DraftModeUIShowDialog().show(
        title: 'Queued Event',
        message: 'Event ${event.id} consumed.',
        confirmLabel: 'OK',
        cancelLabel: 'Later',
        autoConfirm: autoConfirm
    );
    bool acknowledge;
    if (confirmed == true) {
      debugPrint("confirmEvent: agreed");
      acknowledge = await executeEvent(event);
    } else {
      debugPrint("confirmEvent: denied");
      acknowledge = true;
    }
    debugPrint("confirmEvent: acknowledge: $acknowledge");
    return acknowledge;
  }

  // execute can failure, events should not be acknowledged
  Future<bool> executeEvent(ExampleQueueEvent event) async {
    debugPrint("execute event");
    return true;
  }

}