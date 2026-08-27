import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class SiteDirectivesSaveTests: XCTestCase {
    private func makeSite(_ domain: String = "app.test", directives: String? = nil) -> Site {
        Site(
            name: domain,
            path: "/tmp/\(domain)",
            docroot: "/tmp/\(domain)/public",
            domain: domain,
            phpVersion: "8.4",
            type: .php,
            backendPort: 4001,
            frontDirectives: directives
        )
    }

    private final class Recorder {
        var generatedDirectives: [String?] = []
        var persisted: [(UUID, String?)] = []
        var reloadCount = 0
    }

    private func makeSaver(
        site: Site,
        recorder: Recorder,
        validate: @escaping () async -> NginxValidationResult,
        reload: @escaping () async throws -> Void
    ) -> SiteDirectivesSaver {
        var live = [site]
        return SiteDirectivesSaver(
            generate: { sites in
                recorder.generatedDirectives.append(sites.first(where: { $0.id == site.id })?.frontDirectives)
            },
            validate: validate,
            reload: reload,
            liveSites: { live },
            persist: { s, text in
                recorder.persisted.append((s.id, text))
                if let idx = live.firstIndex(where: { $0.id == s.id }) { live[idx].frontDirectives = text }
            }
        )
    }

    func testValidPersistsThenReloads() async throws {
        let site = makeSite(directives: "old")
        let rec = Recorder()
        let saver = makeSaver(site: site, recorder: rec, validate: { .valid }, reload: { rec.reloadCount += 1 })

        try await saver.save(site, "add_header X-A 1;")

        XCTAssertEqual(rec.generatedDirectives, ["add_header X-A 1;"]) // candidate only, no rollback regen
        XCTAssertEqual(rec.persisted.count, 1)
        XCTAssertEqual(rec.persisted.first?.1, "add_header X-A 1;")
        XCTAssertEqual(rec.reloadCount, 1)
    }

    func testEmptyTextPersistsNil() async throws {
        let site = makeSite(directives: "old")
        let rec = Recorder()
        let saver = makeSaver(site: site, recorder: rec, validate: { .valid }, reload: { rec.reloadCount += 1 })

        try await saver.save(site, "   \n  ")

        XCTAssertEqual(rec.persisted.first?.1, nil)
        XCTAssertEqual(rec.reloadCount, 1)
    }

    func testInvalidRevertsGenerateAndDoesNotPersist() async throws {
        let site = makeSite(directives: "old")
        let rec = Recorder()
        let saver = makeSaver(site: site, recorder: rec, validate: { .invalid("boom") }, reload: {
            XCTFail("must not reload on invalid config")
        })

        do {
            try await saver.save(site, "bad;")
            XCTFail("expected throw")
        } catch let error as NginxIncludeSaveError {
            XCTAssertEqual(error, .rejected("boom"))
        }

        XCTAssertEqual(rec.generatedDirectives, ["bad;", "old"]) // candidate then rollback to live
        XCTAssertTrue(rec.persisted.isEmpty)
    }

    func testCouldNotRunPersistsAndThrows() async throws {
        let site = makeSite(directives: "old")
        let rec = Recorder()
        let saver = makeSaver(site: site, recorder: rec, validate: { .couldNotRun }, reload: {
            XCTFail("must not reload when nginx cannot validate")
        })

        do {
            try await saver.save(site, "add_header X-A 1;")
            XCTFail("expected throw")
        } catch let error as NginxIncludeSaveError {
            XCTAssertEqual(error, .couldNotValidate)
        }

        XCTAssertEqual(rec.persisted.first?.1, "add_header X-A 1;")
    }

    func testReloadFailureRevertsPersistAndRegenerates() async throws {
        let site = makeSite(directives: "old")
        let rec = Recorder()
        struct ReloadError: Error {}
        var firstReload = true
        let saver = makeSaver(site: site, recorder: rec, validate: { .valid }, reload: {
            if firstReload { firstReload = false; throw ReloadError() }
            rec.reloadCount += 1
        })

        do {
            try await saver.save(site, "add_header X-A 1;")
            XCTFail("expected throw")
        } catch let error as NginxIncludeSaveError {
            guard case .reloadFailedReverted = error else { return XCTFail("wrong case: \(error)") }
        }

        // persist candidate, then persist previous on rollback
        XCTAssertEqual(rec.persisted.map(\.1), ["add_header X-A 1;", "old"])
        // candidate generate, then rollback generate with reverted live sites
        XCTAssertEqual(rec.generatedDirectives, ["add_header X-A 1;", "old"])
        XCTAssertEqual(rec.reloadCount, 1) // the second (rollback) reload
    }
}
