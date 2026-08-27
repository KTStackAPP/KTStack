import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTSitesPlugin

@MainActor
final class SiteSettingsModelTests: XCTestCase {
    private struct TestError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private final class Recorder {
        var validated: [[String]] = []
        var setAliases: [[String]] = []
        var setEnv: [[String: String]] = []
        var savedDirectives: [String] = []
        var validateError: Error?
        var setAliasesError: Error?
        var directivesError: Error?
    }

    private func makeModel(_ site: SiteSummary, _ rec: Recorder) -> SiteSettingsModel {
        SiteSettingsModel(
            site: site,
            validateAliases: { rec.validated.append($0); if let e = rec.validateError { throw e } },
            setAliases: { rec.setAliases.append($0); if let e = rec.setAliasesError { throw e } },
            setEnvVars: { rec.setEnv.append($0) },
            saveDirectives: { rec.savedDirectives.append($0); if let e = rec.directivesError { throw e } }
        )
    }

    func testAddAliasValidatesThenSetsAndClearsDraft() {
        let rec = Recorder()
        let model = makeModel(makeSite(), rec)
        model.aliasDraft = "  WWW.Example.test "
        model.addAlias()

        XCTAssertEqual(rec.validated.last, ["www.example.test"])
        XCTAssertEqual(rec.setAliases.last, ["www.example.test"])
        XCTAssertEqual(model.aliases, ["www.example.test"])
        XCTAssertEqual(model.aliasDraft, "")
        XCTAssertNil(model.aliasError)
    }

    func testAddAliasInvalidKeepsDraftAndShowsError() {
        let rec = Recorder()
        rec.validateError = TestError(message: "must end in .test")
        let model = makeModel(makeSite(), rec)
        model.aliasDraft = "bad.local"
        model.addAlias()

        XCTAssertTrue(rec.setAliases.isEmpty)
        XCTAssertTrue(model.aliases.isEmpty)
        XCTAssertEqual(model.aliasDraft, "bad.local")
        XCTAssertEqual(model.aliasError, "must end in .test")
    }

    func testRemoveAliasSetsRemaining() {
        let rec = Recorder()
        let model = makeModel(makeSite(aliases: ["a.test", "b.test"]), rec)
        model.removeAlias("a.test")

        XCTAssertEqual(rec.setAliases.last, ["b.test"])
        XCTAssertEqual(model.aliases, ["b.test"])
    }

    func testSaveEnvReservedKeyDoesNotCallContract() {
        let rec = Recorder()
        let model = makeModel(makeSite(), rec)
        model.envRows = [.init(key: "SERVER_NAME", value: "x")]
        model.saveEnv()

        XCTAssertTrue(rec.setEnv.isEmpty)
        XCTAssertNotNil(model.envError)
        XCTAssertFalse(model.envSaved)
    }

    func testSaveEnvValidSkipsBlankKeysAndSaves() {
        let rec = Recorder()
        let model = makeModel(makeSite(), rec)
        model.envRows = [.init(key: " APP_ENV ", value: "local"), .init(key: "  ", value: "ignored")]
        model.saveEnv()

        XCTAssertEqual(rec.setEnv.last, ["APP_ENV": "local"])
        XCTAssertTrue(model.envSaved)
        XCTAssertNil(model.envError)
    }

    func testSaveDirectivesRejectedSetsErrorAndKeepsText() async {
        let rec = Recorder()
        rec.directivesError = NginxIncludeSaveError.rejected("unknown directive foo")
        let model = makeModel(makeSite(), rec)
        model.directives = "foo;"
        await model.saveDirectives()

        XCTAssertEqual(rec.savedDirectives.last, "foo;")
        XCTAssertEqual(model.directives, "foo;")
        XCTAssertNotNil(model.directivesError)
        XCTAssertNil(model.directivesNote)
    }

    func testSaveDirectivesCouldNotValidateTreatedAsSaved() async {
        let rec = Recorder()
        rec.directivesError = NginxIncludeSaveError.couldNotValidate
        let model = makeModel(makeSite(), rec)
        await model.saveDirectives()

        XCTAssertNil(model.directivesError)
        XCTAssertNotNil(model.directivesNote)
    }
}
