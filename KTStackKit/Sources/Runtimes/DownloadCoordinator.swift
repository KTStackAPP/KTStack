import Foundation

final class DownloadCoordinator: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let progressInterval: TimeInterval = 0.1

    private let onProgress: @Sendable (Int64, Int64) -> Void
    private let now: @Sendable () -> Date
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession!
    private var task: URLSessionDownloadTask?
    private var cancelled = false
    private var lastProgress = Date.distantPast
    private var saved: URL?
    private var saveError: Error?

    init(now: @escaping @Sendable () -> Date = { Date() }, onProgress: @escaping @Sendable (Int64, Int64) -> Void) {
        self.onProgress = onProgress
        self.now = now
        super.init()
        session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    }

    func download(_ url: URL) async throws -> URL {
        try RuntimeDownloader.requireHTTPS(url)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                let started = session.downloadTask(with: url)
                lock.lock()
                continuation = cont
                task = started
                let alreadyCancelled = cancelled
                lock.unlock()
                started.resume()
                if alreadyCancelled { started.cancel() }
            }
        } onCancel: { [weak self] in
            self?.cancel()
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let running = task
        lock.unlock()
        running?.cancel()
    }

    func shouldReport(written: Int64, expected: Int64) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let current = now()
        let finished = expected > 0 && written >= expected
        guard finished || current.timeIntervalSince(lastProgress) >= Self.progressInterval else { return false }
        lastProgress = current
        return true
    }

    func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten written: Int64,
        totalBytesExpectedToWrite expected: Int64
    ) {
        if shouldReport(written: written, expected: expected) { onProgress(written, expected) }
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if let url = request.url, RuntimeDownloader.isRedirectAllowed(to: url) {
            completionHandler(request)
        } else {
            completionHandler(nil)
        }
    }

    func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("ktstack-dl-\(UUID().uuidString)")
        do { try FileManager.default.moveItem(at: location, to: dest); saved = dest } catch { saveError = error }
    }

    func urlSession(_ session: URLSession, task _: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let cont = continuation
        continuation = nil
        let wasCancelled = cancelled
        lock.unlock()
        defer { session.finishTasksAndInvalidate() }
        if wasCancelled {
            if let saved { try? FileManager.default.removeItem(at: saved) }
            cont?.resume(throwing: CancellationError())
            return
        }
        if let error { cont?.resume(throwing: error); return }
        if let saved { cont?.resume(returning: saved); return }
        cont?.resume(throwing: saveError ?? RuntimeDownloader.ExtractError(
            message: "Download finished but the file could not be saved."
        ))
    }
}
