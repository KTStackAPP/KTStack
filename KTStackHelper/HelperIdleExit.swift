import Foundation

final class HelperIdleExit {
    private let queue = DispatchQueue(label: "com.ktstack.helper.idle")
    private let delay: TimeInterval
    private var active = 0
    private var pending: DispatchWorkItem?

    init(delay: TimeInterval = 60) {
        self.delay = delay
        queue.async { self.scheduleIfIdle() }
    }

    func opened() {
        queue.async {
            self.active += 1
            self.pending?.cancel()
            self.pending = nil
        }
    }

    func closed() {
        queue.async {
            self.active = max(0, self.active - 1)
            self.scheduleIfIdle()
        }
    }

    private func scheduleIfIdle() {
        guard active == 0 else { return }
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.active == 0 else { return }
            exit(0)
        }
        pending = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
