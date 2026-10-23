import BackgroundTasks
import CryptoKit
import Flutter
import UIKit
import UserNotifications

/// The OS owns transfers. This journal owns installation and survives relaunch.
final class ModelDownloads: NSObject, URLSessionDownloadDelegate {
  static let shared = ModelDownloads()
  static let sessionIdentifier = "dev.theolm.smartnotes.models"
  static let processingIdentifier = "dev.theolm.smartnotes.verify-model"

  private struct Record: Codable {
    let id: String
    let name: String
    let url: String
    let fileName: String
    let folder: String
    let bytes: Int64
    let sha256: String
    var notification: [String: String]?
    var resumed: Bool?
    var token = UUID().uuidString
    var state = "queued"
    var received: Int64 = 0
    var offset: Int64 = 0
    var error: String?
    var verification: VerificationReceipt?
  }

  private struct VerificationReceipt: Codable {
    let version: Int
    let token: String
    let modelId: String
    let folder: String
    let fileName: String
    let digest: String
    let size: Int64
    let modified: Int64

    var dictionary: [String: Any] {
      ["version": version, "token": token, "modelId": modelId,
       "folder": folder, "fileName": fileName, "digest": digest,
       "size": size, "modified": modified]
    }
  }

  private let lock = NSRecursiveLock()
  private var records: [String: Record] = [:]
  private let verification = OperationQueue()
  private var verifying = Set<String>()
  private var enqueued = Set<String>()
  private var backgroundCompletion: (() -> Void)?
  private let root: URL
  private let journal: URL
  private lazy var session: URLSession = {
    let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = true
    config.allowsCellularAccess = true
    config.timeoutIntervalForResource = 7 * 24 * 60 * 60
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()

  private override init() {
    root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    journal = root.appendingPathComponent("model_downloads.json")
    super.init()
    verification.maxConcurrentOperationCount = 1
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    if let data = try? Data(contentsOf: journal),
      let saved = try? JSONDecoder().decode([String: Record].self, from: data)
    {
      records = saved
    }
  }

  private func locked<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }

  private func persist() throws {
    try JSONEncoder().encode(records).write(to: journal, options: .atomic)
    excludeFromBackup(journal)
  }

  private func file(_ record: Record, suffix: String = "") -> URL {
    root.appendingPathComponent(record.folder).appendingPathComponent(record.fileName + suffix)
  }

  private func resumeFile(_ record: Record) -> URL { file(record, suffix: ".resume") }

  private func excludeFromBackup(_ url: URL) {
    var url = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? url.setResourceValues(values)
    try? FileManager.default.setAttributes(
      [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
      ofItemAtPath: url.path)
  }

  func launch() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.processingIdentifier, using: nil) {
      task in
      guard let task = task as? BGProcessingTask else { return }
      let operation = BlockOperation()
      task.expirationHandler = { operation.cancel() }
      operation.addExecutionBlock { [weak self, weak operation] in
        guard let self = self, let operation = operation else { return }
        let pending = self.locked { self.records.values.filter { $0.state == "verifying" } }
        for record in pending {
          if operation.isCancelled { break }
          self.verify(record.id, canContinue: { !operation.isCancelled })
        }
      }
      operation.completionBlock = { [weak operation] in
        let cancelled = operation?.isCancelled ?? true
        if cancelled { self.scheduleVerification() }
        task.setTaskCompleted(success: !cancelled)
      }
      self.verification.addOperation(operation)
    }
    _ = session
    reconcile()
  }

  func attach(_ messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "dev.theolm.smartnotes/model_downloads", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        do {
          switch call.method {
          case "status":
            if UIApplication.shared.applicationState == .active {
              let pending = self.locked {
                self.records.values.filter { $0.state == "verifying" }.map { $0.id }
              }
              for id in pending { self.beginVerification(id) }
            }
            result(
              self.locked {
                self.records.values.map { record -> [String: Any] in
                  let partial = self.file(record, suffix: ".part")
                  let staged =
                    ((try? FileManager.default.attributesOfItem(atPath: partial.path)[.size])
                    as? NSNumber)?.int64Value ?? 0
                  let retained =
                    FileManager.default.fileExists(atPath: self.resumeFile(record).path)
                    ? max(staged, record.received) : staged
                  return [
                    "id": record.id, "state": record.state, "received": record.received,
                    "bytes": record.bytes, "error": record.error as Any? ?? NSNull(),
                    "retained": retained,
                    "token": record.token,
                    "verification": record.verification?.dictionary as Any? ?? NSNull(),
                  ]
                }
              })
          case "start":
            guard let arguments = call.arguments as? [String: Any] else {
              throw DownloadError.invalidRequest
            }
            try self.start(arguments)
            result(nil)
          case "cancel":
            guard let id = call.arguments as? String else { throw DownloadError.invalidRequest }
            try self.cancel(id, completion: result)
          case "notificationsAllowed":
            UNUserNotificationCenter.current().getNotificationSettings { settings in
              let allowed = [.authorized, .provisional, .ephemeral].contains(
                settings.authorizationStatus)
              DispatchQueue.main.async { result(allowed) }
            }
          case "requestNotifications":
            UNUserNotificationCenter.current().requestAuthorization(options: [
              .alert, .sound, .badge,
            ]) { allowed, _ in
              DispatchQueue.main.async { result(allowed) }
            }
          default: result(FlutterMethodNotImplemented)
          }
        } catch {
          result(
            FlutterError(code: "model-download", message: error.localizedDescription, details: nil))
        }
      }
  }

  func handleBackgroundEvents(completion: @escaping () -> Void) {
    backgroundCompletion = completion
    _ = session
  }

  private func start(_ arguments: [String: Any]) throws {
    try locked {
      // Optional persisted fields have defaults only through this initializer.
      guard let id = arguments["id"] as? String,
        let name = arguments["name"] as? String,
        let url = arguments["url"] as? String, URL(string: url)?.scheme == "https",
        let folder = arguments["folder"] as? String,
        folder.range(of: "^[a-z_]+$", options: .regularExpression) != nil,
        let fileName = arguments["fileName"] as? String,
        (fileName as NSString).lastPathComponent == fileName,
        let bytes = arguments["bytes"] as? NSNumber, bytes.int64Value > 0,
        let hash = arguments["sha256"] as? String,
        hash.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil
      else { throw DownloadError.invalidRequest }
      if let existing = records[id], Self.active.contains(existing.state) {
        reconcile()
        return
      }
      if let existing = records[id], existing.state == "completed",
        arguments["repair"] as? Bool != true,
        FileManager.default.fileExists(atPath: file(existing).path)
      {
        return
      }
      guard !records.values.contains(where: { Self.active.contains($0.state) }) else {
        throw DownloadError.busy
      }
      var record = Record(
        id: id, name: name, url: url, fileName: fileName, folder: folder, bytes: bytes.int64Value,
        sha256: hash)
      record.notification = arguments["notification"] as? [String: String]
      if FileManager.default.fileExists(atPath: resumeFile(record).path)
        || FileManager.default.fileExists(atPath: file(record, suffix: ".segment").path)
      {
        record.received = records[id]?.received ?? 0
        record.offset = records[id]?.offset ?? 0
      }
      let directory = file(record).deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      excludeFromBackup(directory)
      records[id] = record
      try persist()
      enqueued.remove(id)
      notify(record, event: "started")
      enqueue(record)
    }
  }

  private func enqueue(_ original: Record) {
    locked {
      guard var record = records[original.id], record.state != "cancelled" else { return }
      guard !enqueued.contains(record.id) else { return }
      enqueued.insert(record.id)
      let staged = file(record, suffix: ".part")
      let stagedSize =
        ((try? FileManager.default.attributesOfItem(atPath: staged.path)[.size]) as? NSNumber)?
        .int64Value
      if stagedSize == record.bytes
        || FileManager.default.fileExists(atPath: file(record, suffix: ".segment").path)
      {
        records[record.id]?.state = "verifying"
        records[record.id]?.received = record.bytes
        try? persist()
        beginVerification(record.id)
        return
      }
      let capacity = try? root.resourceValues(forKeys: [
        .volumeAvailableCapacityForImportantUsageKey
      ]).volumeAvailableCapacityForImportantUsage
      let retained =
        FileManager.default.fileExists(atPath: resumeFile(record).path)
        ? max(stagedSize ?? 0, record.received) : (stagedSize ?? 0)
      // Resuming a legacy Range task still needs room to append its entire
      // retained tail, not just the network bytes that remain to be fetched.
      let hasResume = FileManager.default.fileExists(atPath: resumeFile(record).path)
      let prefix = hasResume ? record.offset : (stagedSize ?? 0)
      let mergeHeadroom = prefix > 0 ? max(0, record.bytes - prefix) : 0
      let required = max(0, record.bytes - retained) + mergeHeadroom + 64 * 1024 * 1024
      if let capacity = capacity, capacity < required {
        fail(record.id, DownloadError.storage)
        return
      }
      let task: URLSessionDownloadTask
      if let resume = try? Data(contentsOf: resumeFile(record)) {
        record.resumed = true
        task = session.downloadTask(withResumeData: resume)
      } else {
        record.resumed = false
        var request = URLRequest(url: URL(string: record.url)!)
        let partial = file(record, suffix: ".part")
        let size =
          ((try? FileManager.default.attributesOfItem(atPath: partial.path)[.size]) as? NSNumber)?
          .int64Value ?? 0
        record.offset = size <= record.bytes ? size : 0
        record.received = record.offset
        if record.offset > 0 {
          request.setValue("bytes=\(record.offset)-", forHTTPHeaderField: "Range")
        }
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        task = session.downloadTask(with: request)
      }
      record.state = "downloading"
      records[record.id] = record
      do { try persist() } catch {
        fail(record.id, error)
        return
      }
      task.taskDescription = record.token
      task.resume()
    }
  }

  /// Reattach to existing tasks; never enqueue a second transfer for an ID.
  private func reconcile() {
    session.getAllTasks { tasks in
      self.locked {
        for record in Array(self.records.values) where Self.active.contains(record.state) {
          if record.state == "verifying" {
            self.beginVerification(record.id)
          } else if !self.enqueued.contains(record.id)
            && !tasks.contains(where: { $0.taskDescription == record.token })
          {
            // A delivered .part file needs verification, not another GET.
            let partial = self.file(record, suffix: ".part")
            let size =
              ((try? FileManager.default.attributesOfItem(atPath: partial.path)[.size]) as? NSNumber)?
              .int64Value
            if size == record.bytes {
              self.records[record.id]?.state = "verifying"
              self.records[record.id]?.received = record.bytes
              try? self.persist()
              self.beginVerification(record.id)
            } else {
              self.enqueue(record)
            }
          }
        }
      }
    }
  }

  private func cancel(_ id: String, completion: @escaping FlutterResult) throws {
    try locked {
      guard let record = records[id] else {
        completion(nil)
        return
      }
      records[id]?.state = "cancelled"
      try persist()
      session.getAllTasks { tasks in
        let group = DispatchGroup()
        for task in tasks where task.taskDescription == record.token {
          guard let download = task as? URLSessionDownloadTask else {
            task.cancel()
            continue
          }
          group.enter()
          download.cancel { data in
            self.locked {
              if self.records[id]?.token == record.token, let data = data {
                try? data.write(to: self.resumeFile(record), options: .atomic)
              }
            }
            group.leave()
          }
        }
        group.notify(queue: .main) { completion(nil) }
      }
      UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
  }

  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard let id = currentID(downloadTask) else { return }
    locked {
      guard var record = records[id], record.token == downloadTask.taskDescription,
        record.state == "downloading"
      else { return }
      let received = min(record.bytes, totalBytesWritten + record.offset)
      // Avoid writing the journal for every network packet.
      if received - record.received >= 1024 * 1024 || received == record.bytes {
        record.received = received
        records[id] = record
        try? persist()
      }
    }
  }

  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard let id = currentID(downloadTask) else { return }
    guard var record = locked({ records[id] }), record.token == downloadTask.taskDescription,
      record.state != "cancelled"
    else { return }
    do {
      try locked {
        guard records[id]?.token == record.token, records[id]?.state != "cancelled" else { return }
        guard let response = downloadTask.response as? HTTPURLResponse else {
          throw DownloadError.response
        }
        let partial = file(record, suffix: ".part")
        if response.statusCode == 206 && record.offset > 0 {
          guard
            response.value(forHTTPHeaderField: "Content-Range")?.hasSuffix(
              "-\(record.bytes - 1)/\(record.bytes)") == true
          else { throw DownloadError.response }
          if record.resumed != true {
            guard
              response.value(forHTTPHeaderField: "Content-Range")
                == "bytes \(record.offset)-\(record.bytes - 1)/\(record.bytes)"
            else { throw DownloadError.response }
          }
          // Save the segment immediately. Merging a large Range response is
          // CPU/I/O work too, and must use the same background budget as hashing.
          let segment = file(record, suffix: ".segment")
          if FileManager.default.fileExists(atPath: segment.path) {
            try FileManager.default.removeItem(at: segment)
          }
          try FileManager.default.moveItem(at: location, to: segment)
          excludeFromBackup(segment)
        } else {
          guard response.statusCode == 200 || (response.statusCode == 206 && record.offset == 0)
          else { throw DownloadError.response }
          if FileManager.default.fileExists(atPath: partial.path) {
            try FileManager.default.removeItem(at: partial)
          }
          try FileManager.default.moveItem(at: location, to: partial)
        }
        try? FileManager.default.removeItem(at: resumeFile(record))
        record.state = "verifying"
        record.received = record.bytes
        try locked {
          guard records[id]?.token == record.token, records[id]?.state != "cancelled" else {
            return
          }
          records[id] = record
          try persist()
          excludeFromBackup(partial)
          beginVerification(id)
        }
      }
    } catch { fail(id, error, token: record.token) }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let error = error as NSError?, let id = currentID(task) else { return }
    locked {
      guard let record = records[id], record.token == task.taskDescription else { return }
      if let resume = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
        try? resume.write(to: resumeFile(record), options: .atomic)
      } else if record.resumed == true && record.state != "cancelled" {
        // Rejected/evicted resume data must not poison every subsequent retry.
        // A fresh task still uses any legacy .part prefix through Range.
        try? FileManager.default.removeItem(at: resumeFile(record))
        records[id]?.token = UUID().uuidString
        records[id]?.state = "queued"
        enqueued.remove(id)
        do { try persist() } catch {
          fail(id, error)
          return
        }
        enqueue(records[id]!)
        return
      }
      if record.state != "cancelled" { fail(id, error) }
    }
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    // Verification has its own background assertion and persisted BGProcessing fallback.
    DispatchQueue.main.async {
      self.backgroundCompletion?()
      self.backgroundCompletion = nil
    }
  }

  private func scheduleVerification() {
    let request = BGProcessingTaskRequest(identifier: Self.processingIdentifier)
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = false
    try? BGTaskScheduler.shared.submit(request)
  }

  private func currentID(_ task: URLSessionTask) -> String? {
    locked { records.values.first { $0.token == task.taskDescription }?.id }
  }

  private func beginVerification(_ id: String) {
    locked {
      guard !verifying.contains(id) else { return }
      let generation = records[id]?.token
      verifying.insert(id)
      scheduleVerification()
      DispatchQueue.main.async {
        let operation = BlockOperation()
        var assertion: UIBackgroundTaskIdentifier = .invalid
        assertion = UIApplication.shared.beginBackgroundTask(withName: "Verify model") {
          operation.cancel()
        }
        operation.addExecutionBlock { [weak operation] in
          guard let operation = operation else { return }
          self.verify(id, canContinue: { !operation.isCancelled })
        }
        operation.completionBlock = {
          self.locked {
            self.verifying.remove(id)
            if self.records[id]?.token != generation && self.records[id]?.state == "verifying" {
              self.beginVerification(id)
            }
          }
          DispatchQueue.main.async {
            if assertion != .invalid { UIApplication.shared.endBackgroundTask(assertion) }
          }
        }
        self.verification.addOperation(operation)
      }
    }
  }

  /// Stream the same catalog hash used by Dart; never load weights into memory.
  private func verify(_ id: String, canContinue: @escaping () -> Bool) {
    guard let record = locked({ records[id] }), record.state == "verifying" else { return }
    do {
      guard try mergeSegment(record, canContinue: canContinue) else { return }
      var partial = file(record, suffix: ".part")
      // Recover death between atomic promotion and persisting completion.
      if !FileManager.default.fileExists(atPath: partial.path) { partial = file(record) }
      let input = try FileHandle(forReadingFrom: partial)
      defer { try? input.close() }
      var hash = SHA256()
      var size: Int64 = 0
      while let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty {
        guard canContinue(),
          locked({ records[id]?.token == record.token && records[id]?.state == "verifying" })
        else { return }
        size += Int64(data.count)
        hash.update(data: data)
      }
      guard canContinue(),
        locked({ records[id]?.token == record.token && records[id]?.state == "verifying" })
      else { return }
      let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
      guard size == record.bytes && digest == record.sha256 else {
        locked {
          if records[id]?.token == record.token && records[id]?.state == "verifying" {
            try? FileManager.default.removeItem(at: partial)
          }
        }
        throw DownloadError.integrity
      }
      try locked {
        guard records[id]?.token == record.token, records[id]?.state == "verifying", canContinue()
        else { return }
        let destination = file(record)
        if partial != destination {
          if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: partial)
          } else {
            try FileManager.default.moveItem(at: partial, to: destination)
          }
        }
        excludeFromBackup(destination)
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        guard let modified = attributes[.modificationDate] as? Date,
          let finalSize = attributes[.size] as? NSNumber else { throw DownloadError.integrity }
        records[id]?.verification = VerificationReceipt(
          version: 1, token: record.token, modelId: record.id,
          folder: record.folder, fileName: record.fileName, digest: record.sha256,
          size: finalSize.int64Value,
          modified: Int64((modified.timeIntervalSince1970 * 1000).rounded(.down)))
        records[id]?.state = "completed"
        records[id]?.received = record.bytes
        try persist()
        notify(record, event: "completed")
      }
    } catch { fail(id, error, token: record.token) }
  }

  /// The persisted Range offset plus actual prefix length form a checkpoint.
  /// Retry only unappended segment bytes, even after process death or expiry.
  private func mergeSegment(_ record: Record, canContinue: @escaping () -> Bool) throws -> Bool {
    let partial = file(record, suffix: ".part")
    let segment = file(record, suffix: ".segment")
    guard FileManager.default.fileExists(atPath: segment.path) else { return true }
    let size =
      ((try? FileManager.default.attributesOfItem(atPath: partial.path)[.size]) as? NSNumber)?
      .int64Value ?? 0
    let isCurrent = {
      canContinue()
        && self.locked {
          self.records[record.id]?.token == record.token
            && self.records[record.id]?.state == "verifying"
        }
    }
    if size != record.bytes {
      guard size >= record.offset && size < record.bytes else { throw DownloadError.response }
      let output = try FileHandle(forWritingTo: partial)
      defer { try? output.close() }
      try output.seekToEnd()
      let input = try FileHandle(forReadingFrom: segment)
      defer { try? input.close() }
      try input.seek(toOffset: UInt64(size - record.offset))
      while let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty {
        let written = try locked {
          guard isCurrent() else { return false }
          try output.write(contentsOf: data)
          return true
        }
        if !written { return false }
      }
      try output.synchronize()
    }
    return try locked {
      guard isCurrent() else { return false }
      records[record.id]?.offset = 0
      try persist()
      try FileManager.default.removeItem(at: segment)
      return true
    }
  }

  private func fail(_ id: String, _ error: Error, token: String? = nil) {
    locked {
      guard let record = records[id], record.state != "cancelled" else { return }
      if let token = token, record.token != token { return }
      records[id]?.state = "failed"
      records[id]?.error = error.localizedDescription
      try? persist()
      notify(record, event: "failed")
    }
  }

  private func notify(_ record: Record, event: String) {
    guard let title = record.notification?[event] else { return }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = record.name
    UNUserNotificationCenter.current().add(
      UNNotificationRequest(identifier: record.id, content: content, trigger: nil))
  }

  private static let active = Set(["queued", "downloading", "verifying"])
  private enum DownloadError: LocalizedError {
    case invalidRequest, busy, response, integrity, storage
    var errorDescription: String? {
      switch self {
      case .invalidRequest: return "Invalid model download request."
      case .busy: return "Another model is downloading."
      case .response: return "Invalid model download response."
      case .integrity: return "Model integrity check failed. Download again."
      case .storage: return "Not enough storage for the model."
      }
    }
  }
}
