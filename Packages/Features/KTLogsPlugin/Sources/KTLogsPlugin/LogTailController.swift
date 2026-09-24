import Combine
import Foundation

@MainActor
public final class LogTailController: ObservableObject {
    @Published public private(set) var lines: [LogLine] = []
    @Published public var filter = "" {
        didSet { recompute() }
    }

    @Published public var isLive = true
    @Published public private(set) var currentSourceID: String?

    private let store: LogLineStore
    private let flushDelay: Duration
    private var reader: LogTailReader?
    private var currentSourceURL: URL?
    private(set) var generation = 0
    private var pending: [String] = []
    private var flushTask: Task<Void, Never>?

    public init(capacity: Int = 5000, flushDelay: Duration = .milliseconds(100)) {
        store = LogLineStore(capacity: capacity)
        self.flushDelay = flushDelay
    }

    public func select(_ source: LogSource?) {
        reader?.stop()
        reader = nil
        generation &+= 1
        resetBuffer()
        currentSourceID = source?.id
        currentSourceURL = source?.url
        guard let source else { return }
        let r = LogTailReader(url: source.url)
        let token = generation
        r.onLines = { [weak self] batch in
            Task { @MainActor in self?.receive(batch, generation: token) }
        }
        reader = r
        r.start()
    }

    public func clear() {
        if let url = currentSourceURL, let fh = try? FileHandle(forWritingTo: url) {
            try? fh.truncate(atOffset: 0)
            try? fh.close()
        }
        resetBuffer()
    }

    func receive(_ batch: [String], generation token: Int) {
        guard token == generation else { return }
        pending.append(contentsOf: batch)
        guard flushTask == nil else { return }
        let delay = flushDelay
        flushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    func flush() {
        flushTask = nil
        guard !pending.isEmpty else { return }
        let (added, firstID) = store.appendIncremental(pending)
        pending = []
        var next = lines
        if let firstID, let first = next.first, first.id < firstID { next.removeAll { $0.id < firstID } }
        next.append(contentsOf: LogLineStore.matching(added, filter))
        lines = next
    }

    private func resetBuffer() {
        flushTask?.cancel()
        flushTask = nil
        pending = []
        store.clear()
        lines = []
    }

    private func recompute() {
        lines = store.filtered(filter)
    }
}
