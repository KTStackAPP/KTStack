import SwiftUI
import XCTest
@testable import KTPluginKit

final class AccessibilityHIGTests: XCTestCase {
    func testToggleCarriesItsLabelAndValue() {
        let toggle = KTToggle("Launch at login", isOn: true) {}
        XCTAssertEqual(toggle.label, "Launch at login")
        XCTAssertEqual(KTToggle.accessibilityValue(isOn: true), "On")
        XCTAssertEqual(KTToggle.accessibilityValue(isOn: false), "Off")
    }

    func testDisplayedShortcutsParseIntoKeyEquivalents() {
        XCTAssertEqual(KTMenuShortcut.parse("⌘D"), KTMenuShortcut(key: "d", command: true, shift: false, option: false))
        XCTAssertEqual(KTMenuShortcut.parse("⌘⇧D"), KTMenuShortcut(key: "d", command: true, shift: true, option: false))
        XCTAssertEqual(KTMenuShortcut.parse("⌘Q")?.key, "q")
        XCTAssertNil(KTMenuShortcut.parse(""))
        XCTAssertNil(KTMenuShortcut.parse("D"), "a shortcut without ⌘ is not bound")
    }
}
