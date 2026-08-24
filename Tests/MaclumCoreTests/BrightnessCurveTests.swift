import XCTest
@testable import MaclumCore

final class BrightnessCurveTests: XCTestCase {
    func testDefaultCurveFollowsSourceBrightness() {
        let curve = BrightnessCurve.default

        XCTAssertEqual(curve.target(for: 0), 0)
        XCTAssertEqual(curve.target(for: 0.25), 25)
        XCTAssertEqual(curve.target(for: 0.5), 50)
        XCTAssertEqual(curve.target(for: 0.75), 75)
        XCTAssertEqual(curve.target(for: 1), 100)
    }

    func testCurveInterpolatesEachSideOfMidpoint() throws {
        let curve = try XCTUnwrap(BrightnessCurve(low: 10, mid: 40, high: 90))

        XCTAssertEqual(curve.target(for: 0.25), 25)
        XCTAssertEqual(curve.target(for: 0.75), 65)
    }

    func testCurveClampsSourceOutsideSupportedRange() throws {
        let curve = try XCTUnwrap(BrightnessCurve(low: 10, mid: 40, high: 90))

        XCTAssertEqual(curve.target(for: -1), 10)
        XCTAssertEqual(curve.target(for: 2), 90)
    }

    func testCurveRoundsFractionalTargetsToNearestWholeDDCValue() throws {
        let curve = try XCTUnwrap(BrightnessCurve(low: 0, mid: 7, high: 100))

        let lowerSegmentTarget: Int = curve.target(for: 0.25)
        let upperSegmentTarget: Int = curve.target(for: 0.75)

        XCTAssertEqual(lowerSegmentTarget, 4)
        XCTAssertEqual(upperSegmentTarget, 54)
    }

    func testCurveRejectsOverlappingOrOutOfRangeAnchors() {
        XCTAssertNil(BrightnessCurve(low: 40, mid: 40, high: 90))
        XCTAssertNil(BrightnessCurve(low: 0, mid: 5, high: 100))
        XCTAssertNil(BrightnessCurve(low: 0, mid: 6, high: 11))
        XCTAssertNil(BrightnessCurve(low: 10, mid: 101, high: 102))
    }

    func testDecodingRejectsCurveThatViolatesAnchorInvariants() {
        let data = #"{"low":40,"mid":40,"high":90}"#.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(BrightnessCurve.self, from: data))
    }

    func testEditingAnchorClampsItBeforeItsNeighbour() throws {
        let curve = try XCTUnwrap(BrightnessCurve(low: 10, mid: 40, high: 90))

        let updated = curve.setting(.low, to: 80)

        XCTAssertEqual(updated.low, 34)
        XCTAssertEqual(updated.mid, 40)
        XCTAssertEqual(updated.high, 90)
    }

    func testEditingMidpointClampsItBetweenBothNeighbours() throws {
        let curve = try XCTUnwrap(BrightnessCurve(low: 10, mid: 40, high: 90))

        let updated = curve.setting(.mid, to: 100)

        XCTAssertEqual(updated.low, 10)
        XCTAssertEqual(updated.mid, 84)
        XCTAssertEqual(updated.high, 90)
    }

    func testEditingHighAnchorClampsItAfterMidpoint() throws {
        let curve = try XCTUnwrap(BrightnessCurve(low: 10, mid: 40, high: 90))

        let updated = curve.setting(.high, to: 10)

        XCTAssertEqual(updated.low, 10)
        XCTAssertEqual(updated.mid, 40)
        XCTAssertEqual(updated.high, 46)
    }

    func testSynchronizerDoesNotSendSameDDCValueTwice() throws {
        let client = RecordingDDCClient()
        let synchronizer = BrightnessSynchronizer(client: client)

        XCTAssertEqual(
            try synchronizer.apply(sourceBrightness: 0.5, curve: .default, displayID: "1"),
            .sent(50)
        )
        XCTAssertEqual(
            try synchronizer.apply(sourceBrightness: 0.5, curve: .default, displayID: "1"),
            .unchanged(50)
        )
        XCTAssertEqual(client.writes, [.init(luminance: 50, displayID: "1")])
    }

    func testSynchronizerSendsValueAfterSwitchingToAnotherDisplay() throws {
        let client = RecordingDDCClient()
        let synchronizer = BrightnessSynchronizer(client: client)

        _ = try synchronizer.apply(sourceBrightness: 0.5, curve: .default, displayID: "1")
        XCTAssertEqual(
            try synchronizer.apply(sourceBrightness: 0.5, curve: .default, displayID: "2"),
            .sent(50)
        )
        XCTAssertEqual(
            client.writes,
            [.init(luminance: 50, displayID: "1"), .init(luminance: 50, displayID: "2")]
        )
    }

    func testPreviewSendsDraggedAnchorValueInsteadOfCurrentCurveResult() throws {
        let client = RecordingDDCClient()
        let synchronizer = BrightnessSynchronizer(client: client)

        XCTAssertEqual(
            try synchronizer.preview(luminance: 34, displayID: "2"),
            .sent(34)
        )
        XCTAssertEqual(
            try synchronizer.preview(luminance: 35, displayID: "2"),
            .sent(35)
        )
        XCTAssertEqual(
            client.writes,
            [.init(luminance: 34, displayID: "2"), .init(luminance: 35, displayID: "2")]
        )
    }

    func testSynchronizerResumesCurveMappingAfterPreviewEnds() throws {
        let client = RecordingDDCClient()
        let synchronizer = BrightnessSynchronizer(client: client)

        _ = try synchronizer.preview(luminance: 34, displayID: "2")
        XCTAssertEqual(
            try synchronizer.apply(sourceBrightness: 0.5, curve: .default, displayID: "2"),
            .sent(50)
        )
        XCTAssertEqual(
            client.writes,
            [.init(luminance: 34, displayID: "2"), .init(luminance: 50, displayID: "2")]
        )
    }
}

private final class RecordingDDCClient: DDCBrightnessWriting {
    struct Write: Equatable {
        let luminance: Int
        let displayID: String?
    }

    private(set) var writes: [Write] = []

    func setLuminance(_ brightness: Int, displayID: String?) throws {
        writes.append(.init(luminance: brightness, displayID: displayID))
    }
}
