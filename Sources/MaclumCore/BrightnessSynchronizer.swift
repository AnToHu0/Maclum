import Foundation

public enum SynchronizationResult: Equatable, Sendable {
    case sent(Int)
    case unchanged(Int)
}

public final class BrightnessSynchronizer {
    private struct Destination: Hashable {
        let displayID: String?
    }

    private let client: any DDCBrightnessWriting
    private var lastSentLuminance: [Destination: Int] = [:]

    public init(client: any DDCBrightnessWriting) {
        self.client = client
    }

    public func apply(sourceBrightness: Double, curve: BrightnessCurve, displayID: String?) throws -> SynchronizationResult {
        let target = curve.target(for: sourceBrightness)
        let destination = Destination(displayID: displayID)
        return try send(target, to: destination)
    }

    public func preview(luminance: Int, displayID: String?) throws -> SynchronizationResult {
        let destination = Destination(displayID: displayID)
        return try send(luminance.clamped(to: 0...100), to: destination)
    }

    private func send(_ luminance: Int, to destination: Destination) throws -> SynchronizationResult {
        guard luminance != lastSentLuminance[destination] else { return .unchanged(luminance) }
        try client.setLuminance(luminance, displayID: destination.displayID)
        lastSentLuminance[destination] = luminance
        return .sent(luminance)
    }
}
