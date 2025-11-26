class ExampleQueueEvent {
  final String id;

  const ExampleQueueEvent({
    required this.id,
  });
}

class ActiveWorkerEvent {
  final Map<String, dynamic> worker;

  const ActiveWorkerEvent(this.worker);
}
