import Foundation

final class PipeCollector: @unchecked Sendable {
    let pipe = Pipe()
    private let lock = NSLock()
    private let group: DispatchGroup
    private var buffer = Data()
    private var finished = false

    init(group: DispatchGroup) {
        self.group = group
        group.enter()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.receive(handle.availableData)
        }
    }

    func detach() -> Data {
        pipe.fileHandleForReading.readabilityHandler = nil
        lock.lock()
        let wasFinished = finished
        finished = true
        let data = buffer
        lock.unlock()
        if !wasFinished { group.leave() }
        try? pipe.fileHandleForReading.close()
        return data
    }

    private func receive(_ chunk: Data) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        guard !chunk.isEmpty else {
            finished = true
            lock.unlock()
            pipe.fileHandleForReading.readabilityHandler = nil
            group.leave()
            return
        }
        buffer.append(chunk)
        lock.unlock()
    }
}
