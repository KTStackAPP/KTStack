import KTStackCore
import XCTest
@testable import KTStackKit

/// Unit tests for the optional-extension catalog: manifest well-formedness, descriptor wiring, and the
/// pure status-resolution logic (built-in vs installed/available/unavailable + the silent-load-failure
/// case). Live `php -m` is exercised by PHPModules' own tests; here the installed set + on-disk flag are
/// injected so the resolution rules are tested without a real PHP binary.
final class PHPExtensionCatalogTests: XCTestCase {
    func testManifestEntriesAreWellFormed() {
        XCTAssertFalse(PHPExtensionCatalog.manifest.isEmpty)
        for r in PHPExtensionCatalog.manifest {
            XCTAssertEqual(r.url.scheme, "https", "\(r.id) must be https")
            XCTAssertEqual(r.url.host, "github.com")
            XCTAssertTrue(r.url.path.contains("/releases/download/"), "\(r.id) must resolve to a release asset")
            XCTAssertEqual(r.sha256.count, 64, "\(r.id) sha256 must be 64 hex chars")
            XCTAssertTrue(r.sha256.allSatisfy(\.isHexDigit), "\(r.id) sha256 must be hex")
            // Filename + id follow the Phase-1 artifact convention php-ext-<ext>-<ver>-arm64.tar.gz.
            XCTAssertEqual(r.url.lastPathComponent, "php-ext-\(r.extID)-\(r.phpVersion)-arm64.tar.gz")
            XCTAssertEqual(r.id, "\(r.extID)-\(r.phpVersion)")
        }
    }

    func testEveryManifestExtensionHasAnOptionalDescriptor() {
        let optionalIDs = Set(PHPExtensionCatalog.optional().map(\.id))
        for r in PHPExtensionCatalog.manifest {
            XCTAssertTrue(
                optionalIDs.contains(r.extID),
                "manifest ext \(r.extID) must have an optional (non-built-in) descriptor"
            )
        }
    }

    func testReleaseLookupMatchesExtAndVersion() {
        let catalog = PHPExtensionCatalog(paths: AppSupportPaths())
        let r = catalog.release("imagick", phpVersion: "8.4")
        XCTAssertEqual(r?.sha256.count, 64)
        XCTAssertEqual(r?.url.lastPathComponent, "php-ext-imagick-8.4-arm64.tar.gz")
        // swoole has no 8.1 build (Swoole 6 is incompatible with PHP 8.1).
        XCTAssertNil(catalog.release("swoole", phpVersion: "8.1"))
        XCTAssertNil(catalog.release("nope", phpVersion: "8.4"))
    }

    func testLoadDirectiveMatchesExtensionClass() {
        // xdebug loads at the Zend layer; the rest are plain module extensions.
        XCTAssertEqual(PHPExtensionCatalog.descriptor("xdebug")?.loadDirective, .zendExtension)
        XCTAssertEqual(PHPExtensionCatalog.descriptor("imagick")?.loadDirective, .module)
    }

    private let catalog = PHPExtensionCatalog(paths: AppSupportPaths())

    func testStatusBuiltInIsAlwaysBuiltIn() {
        let intl = PHPExtensionCatalog.descriptor("intl")!
        XCTAssertTrue(intl.isBuiltIn)
        XCTAssertEqual(catalog.status(intl, phpVersion: "8.4", installed: [], soOnDisk: false), .builtIn)
    }

    func testRedisIsOptionalNotBuiltIn() {
        let redis = PHPExtensionCatalog.descriptor("redis")!
        XCTAssertFalse(redis.isBuiltIn)
    }

    func testXMLWriterIsTrackedAsBuiltIn() {
        let xmlwriter = PHPExtensionCatalog.descriptor("xmlwriter")!
        XCTAssertTrue(xmlwriter.isBuiltIn)
        XCTAssertEqual(catalog.status(xmlwriter, phpVersion: "8.4", installed: [], soOnDisk: false), .builtIn)
    }

    func testStatusOptionalInstalledWhenLoaded() {
        let apcu = PHPExtensionCatalog.descriptor("apcu")!
        XCTAssertEqual(catalog.status(apcu, phpVersion: "8.4", installed: ["apcu"], soOnDisk: true), .installed)
    }

    func testStatusInstalledButFailedToLoadWhenOnDiskButAbsentFromPhpM() {
        let apcu = PHPExtensionCatalog.descriptor("apcu")!
        // .so present on disk but php -m omits it → a silent load failure, not a no-op (red-team H2).
        XCTAssertEqual(
            catalog.status(apcu, phpVersion: "8.4", installed: [], soOnDisk: true),
            .installedButFailedToLoad
        )
    }

    func testStatusAvailableWhenReleaseExistsAndNotInstalled() {
        let swoole = PHPExtensionCatalog.descriptor("swoole")!
        // 8.4 has a release → available; 8.1 has none → unavailable.
        XCTAssertEqual(catalog.status(swoole, phpVersion: "8.4", installed: [], soOnDisk: false), .available)
        XCTAssertEqual(catalog.status(swoole, phpVersion: "8.1", installed: [], soOnDisk: false), .unavailable)
    }

    func testStatusCompiledInIsBuiltInRegardlessOfStaticFlag() {
        let snmp = PHPExtensionCatalog.descriptor("snmp")!
        XCTAssertFalse(snmp.isBuiltIn) // optional descriptor for ≤8.3
        // 8.4/8.5 compile snmp in → built-in, no Uninstall, no reinstall.
        XCTAssertEqual(
            catalog.status(snmp, phpVersion: "8.4", installed: ["snmp"], soOnDisk: false, compiledIn: ["snmp"]),
            .builtIn
        )
    }

    func testStatusCompiledInEmptyKeepsOptionalBehavior() {
        let snmp = PHPExtensionCatalog.descriptor("snmp")!
        // 8.3 has a release, snmp not compiled in → available; installed .so → installed.
        XCTAssertEqual(
            catalog.status(snmp, phpVersion: "8.3", installed: [], soOnDisk: false, compiledIn: []),
            .available
        )
        XCTAssertEqual(
            catalog.status(snmp, phpVersion: "8.3", installed: ["snmp"], soOnDisk: true, compiledIn: []),
            .installed
        )
    }

    func testStaticBuiltInStaysBuiltInWithEmptyCompiledIn() {
        let intl = PHPExtensionCatalog.descriptor("intl")!
        XCTAssertEqual(
            catalog.status(intl, phpVersion: "8.4", installed: [], soOnDisk: false, compiledIn: []),
            .builtIn
        )
    }

    func testCompiledInModulesEmptyWhenBinaryAbsent() {
        let paths = AppSupportPaths(
            root: FileManager.default.temporaryDirectory
                .appendingPathComponent("ktstack-ext-\(UUID().uuidString)")
        )
        XCTAssertTrue(catalogFor(paths).compiledInModules("9.9").isEmpty)
    }

    func testInstalledExtensionsEmptyWhenBinaryAbsent() {
        let paths = AppSupportPaths(
            root: FileManager.default.temporaryDirectory
                .appendingPathComponent("ktstack-ext-\(UUID().uuidString)")
        )
        XCTAssertTrue(catalogFor(paths).installedExtensions("9.9").isEmpty)
    }

    private func catalogFor(_ paths: AppSupportPaths) -> PHPExtensionCatalog {
        PHPExtensionCatalog(paths: paths)
    }
}
