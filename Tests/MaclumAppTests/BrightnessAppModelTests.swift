import XCTest
@testable import MaclumApp
@testable import MaclumCore

@MainActor
final class BrightnessAppModelTests: XCTestCase {
    func testStartReadsActualBrightnessForEveryConnectedDisplay() throws {
        let settingsStore = try makeSettingsStore()
        let ddc = FakeDDCClient(
            displays: [
                DDCDisplay(id: "display-a", name: "Display A"),
                DDCDisplay(id: "display-b", name: "Display B"),
            ],
            luminances: ["display-a": 31, "display-b": 78]
        )
        let model = BrightnessAppModel(
            displayReader: FakeBrightnessReader(value: 0.5),
            ddcClient: ddc,
            settingsStore: settingsStore
        )
        defer { model.stop() }

        model.start()

        XCTAssertEqual(model.displayBrightnesses, ["display-a": 31, "display-b": 78])
        XCTAssertEqual(Set(ddc.readRequests), ["display-a", "display-b"])
        XCTAssertEqual(ddc.readRequests.count, 2)

        ddc.luminances = ["display-a": 44, "display-b": 66]
        ddc.clearReadRequests()

        model.refreshDisplays()

        XCTAssertEqual(model.displayBrightnesses, ["display-a": 44, "display-b": 66])
        XCTAssertEqual(Set(ddc.readRequests), ["display-a", "display-b"])
        XCTAssertEqual(ddc.readRequests.count, 2)
    }

    func testCannotDeleteAConnectedProfileButCanDeleteADisconnectedOne() throws {
        let settingsStore = try makeSettingsStore()
        try settingsStore.save(MaclumSettings(profiles: [
            DisplayProfile(id: "display-a", name: "Display A"),
            DisplayProfile(id: "display-b", name: "Display B"),
        ]))
        let model = BrightnessAppModel(
            displayReader: FakeBrightnessReader(value: 0.5),
            ddcClient: FakeDDCClient(displays: [DDCDisplay(id: "display-a", name: "Display A")]),
            settingsStore: settingsStore
        )
        defer { model.stop() }

        model.start()
        model.removeProfile(id: "display-a")
        model.removeProfile(id: "display-b")

        XCTAssertEqual(model.settings.profiles, [DisplayProfile(id: "display-a", name: "Display A")])
    }

    func testRefreshDisplaysHidesDisplaysThatDoNotAnswerTheDDCProbe() throws {
        let settingsStore = try makeSettingsStore()
        try settingsStore.save(MaclumSettings(profiles: [
            DisplayProfile(id: "display-a", name: "Display A"),
            DisplayProfile(id: "display-b", name: "Display B"),
        ]))
        let ddc = FakeDDCClient(
            displays: [
                DDCDisplay(id: "display-a", name: "Display A"),
                DDCDisplay(id: "display-b", name: "Display B"),
            ],
            luminances: ["display-a": 44],
            failingReadDisplayIDs: ["display-b"]
        )
        let model = BrightnessAppModel(
            displayReader: FakeBrightnessReader(value: 0.5),
            ddcClient: ddc,
            settingsStore: settingsStore
        )
        defer { model.stop() }

        model.start()

        XCTAssertEqual(model.activeProfiles.map(\.id), ["display-a"])
        XCTAssertEqual(model.displayBrightnesses, ["display-a": 44])
        XCTAssertTrue(model.inactiveProfiles.isEmpty)
        XCTAssertEqual(
            try settingsStore.load().profiles.map(\.id),
            ["display-a", "display-b"]
        )

        ddc.failingReadDisplayIDs = []
        ddc.luminances["display-b"] = 66
        model.refreshDisplays()

        XCTAssertEqual(model.activeProfiles.map(\.id), ["display-a", "display-b"])
        XCTAssertEqual(model.displayBrightnesses, ["display-a": 44, "display-b": 66])
        XCTAssertEqual(ddc.readRequests.filter { $0 == "display-b" }.count, 2)
    }

	func testManualThemeSelectionDisablesAutomationAndAppliesTheSelectedTheme() throws {
		let settingsStore = try makeSettingsStore()
		try settingsStore.save(MaclumSettings(theme: ThemeSettings(isAutomaticSwitchingEnabled: true)))
		let appearance = FakeSystemAppearanceController(theme: .light)
		let model = BrightnessAppModel(
			displayReader: FakeBrightnessReader(value: 0.5),
			ddcClient: FakeDDCClient(displays: []),
			settingsStore: settingsStore,
			appearanceController: appearance
		)
		defer { model.stop() }

		model.start()
		appearance.resetAppliedThemes()

		model.setTheme(.dark)

		XCTAssertFalse(model.settings.theme.isAutomaticSwitchingEnabled)
		XCTAssertEqual(model.currentTheme, .dark)
		XCTAssertEqual(appearance.appliedThemes, [.dark])
		XCTAssertEqual(try settingsStore.load().theme.isAutomaticSwitchingEnabled, false)
	}

	func testManualThemeShortcutTogglesTheThemeAndDisablesAutomation() throws {
		let settingsStore = try makeSettingsStore()
		try settingsStore.save(MaclumSettings(theme: ThemeSettings(isAutomaticSwitchingEnabled: true)))
		let appearance = FakeSystemAppearanceController(theme: .light)
		let model = BrightnessAppModel(
			displayReader: FakeBrightnessReader(value: 0.5),
			ddcClient: FakeDDCClient(displays: []),
			settingsStore: settingsStore,
			appearanceController: appearance
		)
		defer { model.stop() }

		model.start()
		appearance.resetAppliedThemes()

		model.performThemeShortcut(.manualToggle)

		XCTAssertFalse(model.settings.theme.isAutomaticSwitchingEnabled)
		XCTAssertEqual(model.currentTheme, .dark)
		XCTAssertEqual(appearance.appliedThemes, [.dark])
	}

	func testManualThemeSelectionCanApplyLightAndDisablesAutomation() throws {
		let settingsStore = try makeSettingsStore()
		try settingsStore.save(MaclumSettings(theme: ThemeSettings(isAutomaticSwitchingEnabled: true)))
		let appearance = FakeSystemAppearanceController(theme: .dark)
		let model = BrightnessAppModel(
			displayReader: FakeBrightnessReader(value: 0.5),
			ddcClient: FakeDDCClient(displays: []),
			settingsStore: settingsStore,
			appearanceController: appearance
		)
		defer { model.stop() }

		model.start()
		appearance.resetAppliedThemes()

		model.setTheme(.light)

		XCTAssertFalse(model.settings.theme.isAutomaticSwitchingEnabled)
		XCTAssertEqual(model.currentTheme, .light)
		XCTAssertEqual(appearance.appliedThemes, [.light])
	}

	func testResumeAutomaticShortcutEnablesAutomationAndImmediatelyAppliesCurrentBrightnessRule() throws {
		let settingsStore = try makeSettingsStore()
		let appearance = FakeSystemAppearanceController(theme: .light)
		let model = BrightnessAppModel(
			displayReader: FakeBrightnessReader(value: 0.2),
			ddcClient: FakeDDCClient(displays: []),
			settingsStore: settingsStore,
			appearanceController: appearance
		)
		defer { model.stop() }

		model.start()
		model.performThemeShortcut(.resumeAutomatic)

		XCTAssertTrue(model.settings.theme.isAutomaticSwitchingEnabled)
		XCTAssertEqual(model.currentTheme, .dark)
		XCTAssertEqual(appearance.appliedThemes, [.dark])
	}

	func testAppearanceErrorDoesNotPreventBrightnessSynchronization() throws {
		let settingsStore = try makeSettingsStore()
		try settingsStore.save(MaclumSettings(theme: ThemeSettings(isAutomaticSwitchingEnabled: true)))
		let ddc = FakeDDCClient(
			displays: [DDCDisplay(id: "display-a", name: "Display A")],
			luminances: ["display-a": 50]
		)
		let appearance = FakeSystemAppearanceController(theme: .light, setError: FakeAppearanceError.denied)
		let model = BrightnessAppModel(
			displayReader: FakeBrightnessReader(value: 0.2),
			ddcClient: ddc,
			settingsStore: settingsStore,
			appearanceController: appearance
		)
		defer { model.stop() }

		model.start()

		XCTAssertEqual(
			ddc.setRequests,
			[FakeDDCClient.SetRequest(brightness: 20, displayID: "display-a")]
		)
		guard case let .error(message) = model.status else {
			return XCTFail("Expected a theme status error")
		}
		XCTAssertTrue(message.contains("Appearance"))
	}

	func testAppearanceReadErrorDoesNotPreventBrightnessSynchronization() throws {
		let settingsStore = try makeSettingsStore()
		try settingsStore.save(MaclumSettings(theme: ThemeSettings(isAutomaticSwitchingEnabled: true)))
		let ddc = FakeDDCClient(
			displays: [DDCDisplay(id: "display-a", name: "Display A")],
			luminances: ["display-a": 50]
		)
		let appearance = FakeSystemAppearanceController(theme: .light, currentError: FakeAppearanceError.denied)
		let model = BrightnessAppModel(
			displayReader: FakeBrightnessReader(value: 0.2),
			ddcClient: ddc,
			settingsStore: settingsStore,
			appearanceController: appearance
		)
		defer { model.stop() }

		model.start()

		XCTAssertEqual(
			ddc.setRequests,
			[FakeDDCClient.SetRequest(brightness: 20, displayID: "display-a")]
		)
		guard case let .error(message) = model.status else {
			return XCTFail("Expected a theme status error")
		}
		XCTAssertTrue(message.contains("Appearance"))
	}

    private func makeSettingsStore() throws -> SettingsStore {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return SettingsStore(fileURL: directory.appending(path: "settings.json"))
    }
}

private final class FakeBrightnessReader: BuiltInBrightnessReading {
    let value: Double

    init(value: Double) {
        self.value = value
    }

    func read() throws -> Double {
        value
    }
}

private final class FakeSystemAppearanceController: SystemAppearanceControlling {
	private(set) var theme: SystemTheme
	private(set) var appliedThemes: [SystemTheme] = []

	private let setError: Error?
	private let currentError: Error?

	init(theme: SystemTheme, setError: Error? = nil, currentError: Error? = nil) {
		self.theme = theme
		self.setError = setError
		self.currentError = currentError
	}

	func currentTheme() throws -> SystemTheme {
		if let currentError {
			throw currentError
		}
		return theme
	}

	func setTheme(_ theme: SystemTheme) throws {
		if let setError {
			throw setError
		}
		self.theme = theme
		appliedThemes.append(theme)
	}

	func resetAppliedThemes() {
		appliedThemes.removeAll()
	}
}

private final class FakeDDCClient: DDCControlling {
	struct SetRequest: Equatable {
		let brightness: Int
		let displayID: String?
	}

    let availableDisplays: [DDCDisplay]
    var luminances: [String: Int]
    var failingReadDisplayIDs: Set<String>
    private(set) var readRequests: [String] = []
	private(set) var setRequests: [SetRequest] = []

    init(
        displays: [DDCDisplay],
        luminances: [String: Int] = [:],
        failingReadDisplayIDs: Set<String> = []
    ) {
        availableDisplays = displays
        self.luminances = luminances
        self.failingReadDisplayIDs = failingReadDisplayIDs
    }

    var isInstalled: Bool { true }

    func displays() throws -> [DDCDisplay] {
        availableDisplays
    }

    func luminance(displayID: String) throws -> Int {
        readRequests.append(displayID)
        if failingReadDisplayIDs.contains(displayID) {
            throw FakeDDCError.readFailed
        }
        return luminances[displayID] ?? 50
    }

    func clearReadRequests() {
        readRequests.removeAll()
    }

	func setLuminance(_ brightness: Int, displayID: String?) throws {
		setRequests.append(SetRequest(brightness: brightness, displayID: displayID))
	}
}

private enum FakeDDCError: Error {
    case readFailed
}

private enum FakeAppearanceError: LocalizedError {
	case denied

	var errorDescription: String? { "Automation permission denied" }
}
