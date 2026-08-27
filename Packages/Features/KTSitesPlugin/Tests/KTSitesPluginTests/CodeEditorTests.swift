import XCTest
@testable import KTSitesPlugin

final class CodeEditorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!

    override func setUp() {
        super.setUp()
        suite = "ktstack-editor-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        suite = nil
        super.tearDown()
    }

    private func url(_ id: String) -> URL { URL(fileURLWithPath: "/Applications/\(id).app") }

    func testNoEditorsInstalledMeansNoPreferred() {
        let catalog = CodeEditorCatalog(locate: { _ in nil }, defaults: defaults)
        XCTAssertTrue(catalog.installed.isEmpty)
        XCTAssertNil(catalog.preferred())
    }

    func testStoredPreferredReturnedWhenInstalled() {
        defaults.set(CodeEditor.phpstorm.rawValue, forKey: CodeEditorCatalog.preferredKey)
        let installed: Set<String> = [CodeEditor.vscode.rawValue, CodeEditor.phpstorm.rawValue]
        let catalog = CodeEditorCatalog(locate: { installed.contains($0) ? self.url($0) : nil }, defaults: defaults)
        XCTAssertEqual(catalog.preferred(), .phpstorm)
    }

    func testStoredPreferredNotInstalledFallsBackToFirst() {
        defaults.set(CodeEditor.cursor.rawValue, forKey: CodeEditorCatalog.preferredKey)
        let catalog = CodeEditorCatalog(
            locate: { $0 == CodeEditor.vscode.rawValue ? self.url($0) : nil }, defaults: defaults
        )
        XCTAssertEqual(catalog.preferred(), .vscode)
    }

    func testGarbageStoredValueFallsBackToFirstInstalled() {
        defaults.set("not.a.bundle.id", forKey: CodeEditorCatalog.preferredKey)
        let catalog = CodeEditorCatalog(
            locate: { $0 == CodeEditor.zed.rawValue ? self.url($0) : nil }, defaults: defaults
        )
        XCTAssertEqual(catalog.preferred(), .zed)
    }

    func testSetPreferredWritesRawValueUnderFrozenKey() {
        let catalog = CodeEditorCatalog(locate: { self.url($0) }, defaults: defaults)
        catalog.setPreferred(.sublime)
        XCTAssertEqual(defaults.string(forKey: "KTStack.preferredEditor"), CodeEditor.sublime.rawValue)
    }

    func testInstalledFollowsCatalogOrder() {
        let present: Set<String> = [CodeEditor.sublime.rawValue, CodeEditor.vscode.rawValue]
        let catalog = CodeEditorCatalog(locate: { present.contains($0) ? self.url($0) : nil }, defaults: defaults)
        XCTAssertEqual(catalog.installed, [.vscode, .sublime]) // CaseIterable order, not insertion
    }
}
