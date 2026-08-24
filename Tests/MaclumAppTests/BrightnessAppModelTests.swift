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

private final class FakeDDCClient: DDCControlling {
    let availableDisplays: [DDCDisplay]
    var luminances: [String: Int]
    var failingReadDisplayIDs: Set<String>
    private(set) var readRequests: [String] = []

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

    func setLuminance(_ brightness: Int, displayID: String?) throws {}
}

private enum FakeDDCError: Error {
    case readFailed
}
