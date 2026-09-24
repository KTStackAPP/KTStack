import KTPluginKit
import KTStackCore
import XCTest
@testable import KTDoctorPlugin

final class NetworkExposureCheckTests: XCTestCase {
    private let paths = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/kt-exposure"))

    private func check(conf: String?) -> DoctorCheck {
        var probes = FakeDoctorProbes.healthy(paths: paths, tld: "test")
        let confPath = paths.nginxConf.path
        probes.readFileFn = { $0.path == confPath ? conf : nil }
        return DoctorChecks.networkExposure(paths: paths, probes: probes)
    }

    func testLoopbackOnlyConfigPasses() {
        let conf = "http {\n    allow 127.0.0.1;\n    allow ::1;\n    deny all;\n    include x;\n    server {\n    }\n}"
        XCTAssertEqual(check(conf: conf).status, .pass)
    }

    func testConfigWithoutHttpLevelDenyWarns() {
        let conf = "http {\n    include x;\n    server {\n        location ~ /\\. { deny all; }\n    }\n}"
        let result = check(conf: conf)
        XCTAssertEqual(result.status, .warn)
        XCTAssertNotNil(result.remedy)
    }

    func testMissingConfigPasses() {
        XCTAssertEqual(check(conf: nil).status, .pass)
    }
}
