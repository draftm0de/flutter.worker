/// Internal envelope that wraps an event before it is delivered to the watcher.
class DraftModeEventElement {
  DraftModeEventElement(
    this.event, {
    this.delay,
  }) : createdAt = DateTime.now();

  final Object? event;
  final Duration? delay;
  final DateTime createdAt;
}
