import Foundation
import KTStackCore

func fail(_ message: String, code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}

let args = CommandLine.arguments
guard args.count >= 2 else { fail("usage: ktstack-resolve <tool> [cwd]", code: 2) }
let tool = args[1]
let cwd = args.count >= 3 ? URL(fileURLWithPath: args[2]) : URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

let paths = AppSupportPaths()
let resolver = ShellToolResolver(paths: paths)

guard resolver.isToolEnabled(tool) else {
    fail("\(tool) is disabled in KTStack shell integration", code: 1)
}

guard let bin = resolver.resolve(tool: tool, cwd: cwd) else {
    fail("no \(tool) binary found or installed in KTStack", code: 127)
}

print(bin.path)
