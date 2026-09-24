import Foundation
import KTStackCore

extension KTLocalIPCSocketListener {
    enum RequestRead {
        case empty
        case tooLarge
        case malformed
        case request(KTIPCRequest)
    }

    static func peerIsCurrentUser(_ fd: Int32) -> Bool {
        var uid: uid_t = 0
        var gid: gid_t = 0
        return getpeereid(fd, &uid, &gid) == 0 && uid == getuid()
    }

    static func serve(_ fd: Int32, dispatcher: KTIPCCommandDispatcher, timeout: Int) {
        applySocketOptions(fd, timeout: timeout)
        switch readRequest(fd, limit: maxRequestBytes) {
        case .empty:
            close(fd)
        case .tooLarge:
            respond(fd, .fail("Request exceeds \(maxRequestBytes) bytes"))
        case .malformed:
            respond(fd, .fail("Malformed JSON request"))
        case let .request(request):
            Task {
                let response = await dispatcher.dispatch(request)
                DispatchQueue.global(qos: .userInitiated).async { respond(fd, response) }
            }
        }
    }

    static func readRequest(_ fd: Int32, limit: Int) -> RequestRead {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = read(fd, &buffer, buffer.count)
            if count < 0 {
                if errno == EINTR { continue }
                break
            }
            if count == 0 { break }
            data.append(buffer, count: count)
            if data.count > limit { return .tooLarge }
            if buffer[count - 1] == UInt8(ascii: "}"),
               let request = try? JSONDecoder().decode(KTIPCRequest.self, from: data) {
                return .request(request)
            }
        }
        guard !data.isEmpty else { return .empty }
        guard let request = try? JSONDecoder().decode(KTIPCRequest.self, from: data) else { return .malformed }
        return .request(request)
    }

    private static func applySocketOptions(_ fd: Int32, timeout: Int) {
        var interval = timeval(tv_sec: timeout, tv_usec: 0)
        let size = socklen_t(MemoryLayout<timeval>.size)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &interval, size)
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &interval, size)
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    }

    private static func respond(_ fd: Int32, _ response: KTIPCResponse) {
        defer { close(fd) }
        guard let data = try? JSONEncoder().encode(response) else { return }
        data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < data.count {
                let written = write(fd, base.advanced(by: offset), data.count - offset)
                if written <= 0 {
                    if errno == EINTR { continue }
                    return
                }
                offset += written
            }
        }
    }
}
