/// Bridges Flutter calls to the underlying `TimedWorker` singleton and keeps the
/// platform channel wiring plus BGProcessing registration in one place.
import Flutter
import UIKit
import BackgroundTasks

public class TimedWorkerPlugin: NSObject, FlutterPlugin {
  private static let channelName = "timed_worker_ios/channel"
  private static let processingId = "timed.worker.processing"

  private var channel: FlutterMethodChannel!

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = TimedWorkerPlugin()
    instance.channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: instance.channel)

    // Register BGProcessing to resume (optional)
    BGTaskScheduler.shared.register(forTaskWithIdentifier: processingId, using: nil) { task in
      guard let ptask = task as? BGProcessingTask else { return }
      instance.handleProcessing(task: ptask)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let worker = TimedWorker.shared
    switch call.method {
      case "start":
        guard let args = call.arguments as? [String: Any],
              let durationMs = args["durationMs"] as? Int,
              let taskId = args["taskId"] as? String else {
          result(FlutterError(code: "ARG", message: "Missing args", details: nil)); return
        }
        worker.start(taskId: taskId, durationMs: durationMs, emit: emit)
        result(nil)

      case "cancel":
        let args = call.arguments as? [String: Any]
        let fromUi = args?["fromUi"] as? Bool ?? false
        worker.cancel(fromUi: fromUi, emit: emit)
        result(nil)

      case "status":
        result(worker.statusDict())

      case "completed":
        let args = call.arguments as? [String: Any]
        let fromUi = args?["fromUi"] as? Bool ?? false
        worker.complete(fromUi: fromUi, emit: emit)
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
    }
  }

  private func emit(_ event: String, _ payload: [String: Any]) {
    let send = {
      self.channel.invokeMethod(event, arguments: payload)
    }
    if Thread.isMainThread {
      send()
    } else {
      DispatchQueue.main.async(execute: send)
    }
  }

  // Optional: schedule a deferred resume if we were cut off
  private func scheduleProcessing(earliest: TimeInterval = 60) {
    let req = BGProcessingTaskRequest(identifier: Self.processingId)
    req.requiresNetworkConnectivity = false
    req.earliestBeginDate = Date(timeIntervalSinceNow: earliest)
    try? BGTaskScheduler.shared.submit(req)
  }

  private func handleProcessing(task: BGProcessingTask) {
    task.expirationHandler = { [weak self] in
      guard let self else { return }
      TimedWorker.shared.expire(emit: self.emit)
    }
    TimedWorker.shared.resumeIfPending(emit: emit) { finished in
      task.setTaskCompleted(success: finished)
    }
  }
}
