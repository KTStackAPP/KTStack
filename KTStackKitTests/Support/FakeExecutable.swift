import Foundation

struct FakeExecutable {
    let url: URL

    var path: String {
        url.path
    }

    static func make(named name: String, script: String, in directory: URL? = nil) throws -> FakeExecutable {
        let dir = directory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("ktstack-fake-exec-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data("#!/bin/sh\n\(script)\n".utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return FakeExecutable(url: url)
    }

    static func emittingStderr(bytes: Int, named name: String = "noisy", in directory: URL? = nil) throws -> FakeExecutable {
        try make(named: name, script: "head -c \(bytes) /dev/zero >&2", in: directory)
    }

    static func sleeping(seconds: Int, named name: String = "sleeper", in directory: URL? = nil) throws -> FakeExecutable {
        try make(named: name, script: "trap '' TERM\nexec /bin/sleep \(seconds)", in: directory)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
