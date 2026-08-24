import XCTest
@testable import MaclumCore

final class DisplayProfileTests: XCTestCase {
    func testSynchronizingProfilesPreservesKnownCurvesAndKeepsDisconnectedProfiles() throws {
        let tunedCurve = try XCTUnwrap(BrightnessCurve(low: 10, mid: 40, high: 90))
        let disconnectedCurve = try XCTUnwrap(BrightnessCurve(low: 20, mid: 50, high: 80))
        var settings = MaclumSettings(profiles: [
            DisplayProfile(id: "display-a", name: "Old name", curve: tunedCurve),
            DisplayProfile(id: "display-c", name: "Disconnected display", curve: disconnectedCurve),
        ])
        let displays = [
            DDCDisplay(id: "display-b", name: "Display B"),
            DDCDisplay(id: "display-a", name: "Display A"),
        ]

        let didChange = settings.synchronizeProfiles(with: displays)

        XCTAssertTrue(didChange)
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: settings.profiles.map { ($0.id, $0) }),
            [
                "display-b": DisplayProfile(id: "display-b", name: "Display B", curve: .default),
                "display-a": DisplayProfile(id: "display-a", name: "Display A", curve: tunedCurve),
                "display-c": DisplayProfile(id: "display-c", name: "Disconnected display", curve: disconnectedCurve),
            ]
        )
        XCTAssertEqual(
            settings.activeProfiles(for: displays),
            [
                DisplayProfile(id: "display-b", name: "Display B", curve: .default),
                DisplayProfile(id: "display-a", name: "Display A", curve: tunedCurve),
            ]
        )
        XCTAssertEqual(
            settings.inactiveProfiles(for: displays),
            [DisplayProfile(id: "display-c", name: "Disconnected display", curve: disconnectedCurve)]
        )
    }

    func testUpdatingOneProfileCurveDoesNotChangeAnyOtherProfile() throws {
        let firstCurve = try XCTUnwrap(BrightnessCurve(low: 10, mid: 40, high: 90))
        let secondCurve = try XCTUnwrap(BrightnessCurve(low: 20, mid: 50, high: 80))
        let updatedCurve = try XCTUnwrap(BrightnessCurve(low: 15, mid: 45, high: 85))
        var settings = MaclumSettings(profiles: [
            DisplayProfile(id: "display-a", name: "Display A", curve: firstCurve),
            DisplayProfile(id: "display-b", name: "Display B", curve: secondCurve),
        ])

        settings.setCurve(updatedCurve, for: "display-a")

        XCTAssertEqual(settings.profiles.count, 2)
        XCTAssertEqual(settings.profiles.filter { $0.id == "display-a" }.count, 1)
        XCTAssertEqual(settings.profiles.filter { $0.id == "display-b" }.count, 1)
        XCTAssertEqual(settings.profiles.first(where: { $0.id == "display-a" })?.curve, updatedCurve)
        XCTAssertEqual(settings.profiles.first(where: { $0.id == "display-b" })?.curve, secondCurve)
    }

    func testDecodingLegacySingleDisplaySettingsMigratesToOneProfile() throws {
        let data = #"{"curve":{"low":10,"mid":40,"high":90},"selectedDisplayID":"display-a"}"#.data(using: .utf8)!

        let settings = try JSONDecoder().decode(MaclumSettings.self, from: data)

        XCTAssertEqual(settings.profiles.count, 1)
        XCTAssertEqual(settings.profiles[0].id, "display-a")
        XCTAssertEqual(settings.profiles[0].curve, try XCTUnwrap(BrightnessCurve(low: 10, mid: 40, high: 90)))
    }

    func testRemovingAProfileLeavesOtherSavedProfilesUntouched() throws {
        let secondCurve = try XCTUnwrap(BrightnessCurve(low: 20, mid: 50, high: 80))
        var settings = MaclumSettings(profiles: [
            DisplayProfile(id: "display-a", name: "Display A"),
            DisplayProfile(id: "display-b", name: "Display B", curve: secondCurve),
        ])

        let didRemove = settings.removeProfile(id: "display-b")

        XCTAssertTrue(didRemove)
        XCTAssertEqual(settings.profiles, [DisplayProfile(id: "display-a", name: "Display A")])
    }

    func testRemovingAnUnknownProfileKeepsSettingsUnchanged() {
        var settings = MaclumSettings(profiles: [DisplayProfile(id: "display-a", name: "Display A")])

        let didRemove = settings.removeProfile(id: "missing")

        XCTAssertFalse(didRemove)
        XCTAssertEqual(settings.profiles, [DisplayProfile(id: "display-a", name: "Display A")])
    }
}
