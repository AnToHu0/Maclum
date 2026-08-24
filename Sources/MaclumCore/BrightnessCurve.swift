import Foundation

public enum CurveAnchor: String, CaseIterable, Codable, Sendable {
    case low
    case mid
    case high
}

/// A valid three-anchor mapping from built-in brightness to DDC luminance.
///
/// The anchors represent source brightness levels 0%, 50%, and 100%. Their
/// target values are deliberately strict so the controls on the shared track
/// can neither overlap nor cross.
public struct BrightnessCurve: Codable, Equatable, Sendable {
    public static let minimumAnchorGap = 6

    public let low: Int
    public let mid: Int
    public let high: Int

    public static let `default` = BrightnessCurve(low: 0, mid: 50, high: 100)!

    public init?(low: Int, mid: Int, high: Int) {
        guard Self.supports(low), Self.supports(mid), Self.supports(high),
              low + Self.minimumAnchorGap <= mid,
              mid + Self.minimumAnchorGap <= high
        else {
            return nil
        }

        self.low = low
        self.mid = mid
        self.high = high
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let low = try container.decode(Int.self, forKey: .low)
        let mid = try container.decode(Int.self, forKey: .mid)
        let high = try container.decode(Int.self, forKey: .high)

        guard let curve = BrightnessCurve(low: low, mid: mid, high: high) else {
            throw DecodingError.dataCorruptedError(
                forKey: .mid,
                in: container,
                debugDescription: "Brightness curve anchors must stay in 0...100 and be separated by at least \(Self.minimumAnchorGap)."
            )
        }
        self = curve
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(low, forKey: .low)
        try container.encode(mid, forKey: .mid)
        try container.encode(high, forKey: .high)
    }

    public func target(for sourceBrightness: Double) -> Int {
        let source = sourceBrightness.clamped(to: 0...1)
        let rawTarget: Double

        if source <= 0.5 {
            rawTarget = Double(low) + (Double(mid - low) * (source / 0.5))
        } else {
            rawTarget = Double(mid) + (Double(high - mid) * ((source - 0.5) / 0.5))
        }

        return Int(rawTarget.rounded(.toNearestOrAwayFromZero)).clamped(to: 0...100)
    }

    public func setting(_ anchor: CurveAnchor, to requestedValue: Int) -> BrightnessCurve {
        switch anchor {
        case .low:
            return BrightnessCurve(
                low: requestedValue.clamped(to: 0...(mid - Self.minimumAnchorGap)),
                mid: mid,
                high: high
            )!
        case .mid:
            return BrightnessCurve(
                low: low,
                mid: requestedValue.clamped(to: (low + Self.minimumAnchorGap)...(high - Self.minimumAnchorGap)),
                high: high
            )!
        case .high:
            return BrightnessCurve(
                low: low,
                mid: mid,
                high: requestedValue.clamped(to: (mid + Self.minimumAnchorGap)...100)
            )!
        }
    }

    private static func supports(_ value: Int) -> Bool {
        (0...100).contains(value)
    }

    private enum CodingKeys: String, CodingKey {
        case low
        case mid
        case high
    }
}
