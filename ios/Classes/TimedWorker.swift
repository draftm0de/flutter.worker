import UIKit
import BackgroundTasks

final class TimedWorker {
  static let shared = TimedWorker()

  private var bgTask: UIBackgroundTaskIdentifier = .invalid
  private var timer: DispatchSourceTimer?
  private var endTs: TimeInterval = 0
  private(set) var taskId: String?
  private(set) var isRunning = false

  private let queue = DispatchQueue(label: "timedworker.queue")

  private var remainingMs: Int {
    get { UserDefaults.standard.integer(forKey: "tw.remainingMs") }
    set { UserDefaults.standard.set(newValue, forKey: "tw.remainingMs") }
  }
  private var storedTaskId: String? {
    get { UserDefaults.standard.string(forKey: "tw.taskId") }
    set { UserDefaults.standard.set(newValue, forKey: "tw.taskId") }
  }

  func start(taskId: String, durationMs: Int,
             emit: @escaping (_ event: String, _ payload: [String: Any]) -> Void) {
    cancel()
    self.taskId = taskId
    self.storedTaskId = taskId
    self.endTs = Date().timeIntervalSince1970 + Double(durationMs)/1000.0
    self.remainingMs = durationMs
    self.isRunning = true

    beginBG(emit: emit)
    tickLoop(emit: emit)
    emit("worker_started", ["taskId": taskId, "remainingMs": remainingMs])
  }

  func cancel(fromUi: Bool = false,
              emit: ((_ event: String, _ payload: [String: Any]) -> Void)? = nil) {
    let hadTask = isRunning
    isRunning = false
    stopTimer()
    endBG()
    remainingMs = 0
    storedTaskId = nil
    if hadTask {
      emit?("worker_cancelled", [
        "taskId": taskId ?? "",
        "fromUi": fromUi,
      ])
    }
    taskId = nil
  }

  func expire(emit: @escaping (_ event: String, _ payload: [String: Any]) -> Void) {
    isRunning = false
    stopTimer()
    endBG()
    emit("worker_expired", ["taskId": taskId ?? ""])
  }

  func statusDict() -> [String: Any] {
    [
      "isRunning": isRunning,
      "taskId": taskId ?? NSNull(),
      "remainingMs": remainingMs
    ]
  }

  func resumeIfPending(emit: @escaping (_ event: String, _ payload: [String: Any]) -> Void,
                       completion: @escaping (Bool) -> Void) {
    guard let id = storedTaskId, remainingMs > 0 else {
      completion(true); return
    }
    taskId = id
    endTs = Date().timeIntervalSince1970 + Double(remainingMs)/1000.0
    isRunning = true
    beginBG(emit: emit)
    tickLoop(emit: emit)
    completion(true)
  }

  func complete(fromUi: Bool = false,
                emit: @escaping (_ event: String, _ payload: [String: Any]) -> Void) {
    guard isRunning else { return }
    isRunning = false
    stopTimer()
    endBG()
    remainingMs = 0
    storedTaskId = nil
    emit("worker_completed", [
      "taskId": taskId ?? "",
      "fromUi": fromUi,
    ])
    taskId = nil
  }

  private func beginBG(emit: @escaping (_ event: String, _ payload: [String: Any]) -> Void) {
    if bgTask == .invalid {
      bgTask = UIApplication.shared.beginBackgroundTask(withName: "TimedWorker") { [weak self] in
        guard let self else { return }
        self.expire(emit: emit)
      }
    }
  }

  private func endBG() {
    if bgTask != .invalid {
      UIApplication.shared.endBackgroundTask(bgTask)
      bgTask = .invalid
    }
  }

  private func tickLoop(emit: @escaping (_ event: String, _ payload: [String: Any]) -> Void) {
    stopTimer()
    let t = DispatchSource.makeTimerSource(queue: queue)
    t.schedule(deadline: .now(), repeating: .milliseconds(500))
    t.setEventHandler { [weak self] in
      guard let self, self.isRunning else { return }
      let now = Date().timeIntervalSince1970
      let remaining = max(0, self.endTs - now)
      self.remainingMs = Int(remaining * 1000)

      emit("worker_progress", ["taskId": self.taskId ?? "", "remainingMs": self.remainingMs])

      if self.remainingMs <= 0 {
        self.complete(fromUi: false, emit: emit)
      }
    }
    timer = t
    t.resume()
  }

  private func stopTimer() {
    timer?.cancel()
    timer = nil
  }
}
