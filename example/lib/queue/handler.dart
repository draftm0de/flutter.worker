import 'package:draftmode_ui/components/dialog.dart';
import 'package:draftmode_worker/event.dart';
import 'package:flutter/cupertino.dart';

import 'event.dart';

class ExampleQueueHandler {

  Future<bool> handleBackendEvent(DraftModeEventMessage message) async {
    final event = message.event;
    if (event is ExampleQueueEvent) {
      debugPrint('handler:handleBackendEvent: ${event.id} (${message.state}) consuming');
    }
    bool acknowledge = true;
    debugPrint('handler:handleBackendEvents: acknowledge: $acknowledge');
    return acknowledge;
  }

  Future<bool> handleForegroundEvent(DraftModeEventMessage message) async {
    final event = message.event;
    bool acknowledge = true;
    if (event is ExampleQueueEvent) {
      debugPrint('handler:handleForegroundEvent: ${event.id} (${message.state}) consuming');
      if (message.autoConfirm != null) {
        debugPrint("handler:handleForegroundEvent: event with autoConfirm");
        switch (message.state) {
          case DraftModeEventMessageState.expired:
          case DraftModeEventMessageState.completed:
            acknowledge = await executeEvent(event);
          break;
          case DraftModeEventMessageState.pending:
            acknowledge = await confirmEvent(event, message.autoConfirm);
          break;
          default:
            acknowledge = false;
            break;
        }
      } else {
        acknowledge = await confirmEvent(event, null);
      }
    } else {
      debugPrint('handler:handleForegroundEvent: ${event.id} (${message.state}) unknown');
      acknowledge = false;
    }
    debugPrint('handler:handleForegroundEvent: acknowledge: $acknowledge');
    return acknowledge;
  }


  Future<bool> confirmEvent(ExampleQueueEvent event, Duration? autoConfirm) async {
    final confirmed = await const DraftModeUIShowDialog().show(
        title: 'Queued Event',
        message: 'Event ${event.id} consumed.',
        confirmLabel: 'Yey',
        cancelLabel: 'No',
        autoConfirm: autoConfirm
    );
    bool acknowledge;
    if (confirmed == true) {
      debugPrint("handler:confirmEvent: agreed");
      acknowledge = await executeEvent(event);
    } else {
      debugPrint("handler:confirmEvent: denied");
      acknowledge = true;
    }
    debugPrint("handler:confirmEvent: acknowledge: $acknowledge");
    return acknowledge;
  }

  // execute can failure, events should not be acknowledged
  Future<bool> executeEvent(ExampleQueueEvent event) async {
    debugPrint("handler:execute event");
    return true;
  }

}