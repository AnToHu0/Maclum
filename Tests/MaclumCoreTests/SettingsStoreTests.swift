import XCTest
@testable import MaclumCore

final class SettingsStoreTests: XCTestCase {
    func testLoadRejectsSettingsWithAnInvalidCurve() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appending(path: "settings.json")
        try #"{"curve":{"low":40,"mid":40,"high":90},"selectedDisplayID":"display"}"#
            .data(using: .utf8)!
            .write(to: fileURL)
        let store = SettingsStore(fileURL: fileURL)

        XCTAssertThrowsError(try store.load())
    }

    func testRoundTripsValidSettings() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SettingsStore(fileURL: directory.appending(path: "settings.json"))
        let expected = MaclumSettings(profiles: [
            DisplayProfile(
                id: "287C65F4-3027-4BFD-9FD9-056FF307AFFA",
                name: "Dell U2725QE",
                curve: try XCTUnwrap(BrightnessCurve(low: 10, mid: 40, high: 90))
            ),
            DisplayProfile(
                id: "F245CD07-1B94-42AE-ABB4-7D5519E1BDEF",
                name: "Studio Display",
                curve: try XCTUnwrap(BrightnessCurve(low: 20, mid: 50, high: 80))
            ),
		], theme: ThemeSettings(
			isAutomaticSwitchingEnabled: true,
			automaticThreshold: 42,
			manualToggleShortcut: ThemeShortcut(keyCode: 2, modifiers: [.command, .option]),
			resumeAutomaticShortcut: ThemeShortcut(keyCode: 0, modifiers: [.command, .control])
		))

        try store.save(expected)

        XCTAssertEqual(try store.load(), expected)
    }

	func testDecodingExistingSettingsUsesManualThemeDefaults() throws {
		let settings = try JSONDecoder().decode(
			MaclumSettings.self,
			from: #"{"profiles":[]}"#.data(using: .utf8)!
		)

		XCTAssertEqual(settings.theme, ThemeSettings())
	}
}
