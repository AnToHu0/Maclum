import XCTest
@testable import MaclumCore

final class ThemeSettingsTests: XCTestCase {
	func testAutomaticThemeUsesThresholdAndRetainsCurrentThemeInsideHysteresisBand() {
		let settings = ThemeSettings(isAutomaticSwitchingEnabled: true, automaticThreshold: 35)

		XCTAssertEqual(settings.automaticTheme(for: 0.32, currentTheme: .light), .dark)
		XCTAssertEqual(settings.automaticTheme(for: 0.33, currentTheme: .light), .dark)
		XCTAssertEqual(settings.automaticTheme(for: 0.37, currentTheme: .dark), .light)
		XCTAssertEqual(settings.automaticTheme(for: 0.38, currentTheme: .dark), .light)
		XCTAssertEqual(settings.automaticTheme(for: 0.35, currentTheme: .dark), .dark)
		XCTAssertEqual(settings.automaticTheme(for: 0.35, currentTheme: .light), .light)
	}

	func testManualShortcutAssignmentClearsTheDuplicateAutomaticShortcut() {
		let shortcut = ThemeShortcut(keyCode: 2, modifiers: [.command, .option])
		var settings = ThemeSettings(resumeAutomaticShortcut: shortcut)

		settings.setShortcut(shortcut, for: .manualToggle)

		XCTAssertEqual(settings.manualToggleShortcut, shortcut)
		XCTAssertNil(settings.resumeAutomaticShortcut)
	}

	func testAutomaticShortcutAssignmentClearsTheDuplicateManualShortcut() {
		let shortcut = ThemeShortcut(keyCode: 0, modifiers: [.command, .control])
		var settings = ThemeSettings(manualToggleShortcut: shortcut)

		settings.setShortcut(shortcut, for: .resumeAutomatic)

		XCTAssertNil(settings.manualToggleShortcut)
		XCTAssertEqual(settings.resumeAutomaticShortcut, shortcut)
	}

	func testShortcutWithoutCommandControlOrOptionIsNotAssigned() {
		var settings = ThemeSettings()

		settings.setShortcut(ThemeShortcut(keyCode: 2, modifiers: [.shift]), for: .manualToggle)
		settings.setShortcut(ThemeShortcut(keyCode: 0, modifiers: [.shift]), for: .resumeAutomatic)

		XCTAssertNil(settings.manualToggleShortcut)
		XCTAssertNil(settings.resumeAutomaticShortcut)
	}
}
