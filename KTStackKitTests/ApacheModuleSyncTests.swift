import XCTest
@testable import KTStackKit

// The Apache backend can only load modules the relocatable tarball actually ships. The `LoadModule`
// lines in ApacheBackend.loadModules and the MODULES array in scripts/build-apache-relocatable.sh
// must name the exact same .so set, or httpd fails to start at runtime (a load-time error the app
// only sees when a user switches a site to Apache). This test fails loudly if either side drifts.
final class ApacheModuleSyncTests: XCTestCase {
    func testLoadModulesMatchesBuildScriptModuleSet() throws {
        let loaded = Self.modulesLoadedBySwift()
        let built = try Self.modulesBuiltByScript()
        XCTAssertFalse(loaded.isEmpty, "parsed no LoadModule lines from ApacheBackend.loadModules")
        XCTAssertEqual(
            loaded, built,
            "ApacheBackend.loadModules and build-apache-relocatable.sh MODULES disagree. "
                + "Only in Swift: \(loaded.subtracting(built).sorted()). "
                + "Only in script: \(built.subtracting(loaded).sorted())."
        )
    }

    // Every `LoadModule <name>_module modules/<file>.so` → the `.so` basename without extension.
    private static func modulesLoadedBySwift() -> Set<String> {
        let regex = try! NSRegularExpression(pattern: #"modules/(mod_[A-Za-z0-9_]+)\.so"#)
        let text = ApacheBackend.loadModules
        let range = NSRange(text.startIndex..., in: text)
        var names = Set<String>()
        for match in regex.matches(in: text, range: range) {
            if let r = Range(match.range(at: 1), in: text) { names.insert(String(text[r])) }
        }
        return names
    }

    // Parse the MODULES=( ... ) array from the build script; entries are bare `mod_x` tokens.
    private static func modulesBuiltByScript() throws -> Set<String> {
        let script = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // KTStackKitTests/
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("scripts/build-apache-relocatable.sh")
        let content = try String(contentsOf: script, encoding: .utf8)
        guard let open = content.range(of: "MODULES=("),
              let close = content.range(of: ")", range: open.upperBound ..< content.endIndex)
        else {
            XCTFail("MODULES=( ... ) block not found in \(script.path)")
            return []
        }
        let body = content[open.upperBound ..< close.lowerBound]
        let tokens = body.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" })
        return Set(tokens.map(String.init).filter { $0.hasPrefix("mod_") }.map { "\($0)" })
    }
}
