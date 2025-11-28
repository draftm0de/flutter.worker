/// Possible lifecycle states for a queued DraftMode event.
enum DraftModeEventMessageState { pending, completed, expired, cancelled }

/// Internal record that wraps an event before it is delivered to the watcher.
class DraftModeEventMessage<T> {
  DraftModeEventMessage(
    this.id,
    this.event, {
    this.autoConfirm,
  })  : createdAt = DateTime.now(),
        state = DraftModeEventMessageState.pending,
        ready = autoConfirm == null;

  final String id;
  final T event;
  final Duration? autoConfirm;
  final DateTime createdAt;
  DraftModeEventMessageState state;
  bool ready;
  Duration? remaining;

  bool get managedByWorker => autoConfirm != null;
}
