/// Internal envelope that wraps an event before it is delivered to the watcher.
class DraftModeEventElement<T> {
  DraftModeEventElement(
    this.id,
    this.event, {
    this.delay,
  }) : createdAt = DateTime.now();

  final String id;
  final T event;
  final Duration? delay;
  final DateTime createdAt;
}
