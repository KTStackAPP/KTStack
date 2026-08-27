import Foundation

// Deterministic gate cho stub async: chặn tới khi test gọi release, không phụ thuộc wall-clock.
final class ReleaseGate: @unchecked Sendable {
    private let lock = NSLock()
    private var cont: CheckedContinuation<Void, Never>?
    private var released = false

    func wait() async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            lock.lock()
            if released { lock.unlock(); c.resume() } else { cont = c; lock.unlock() }
        }
    }

    func release() {
        lock.lock()
        if let c = cont { cont = nil; lock.unlock(); c.resume() } else { released = true; lock.unlock() }
    }
}
