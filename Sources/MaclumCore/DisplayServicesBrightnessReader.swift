import CoreGraphics
import Darwin
import Foundation

public enum BuiltInBrightnessError: LocalizedError {
    case noBuiltInDisplay
    case displayServicesUnavailable
    case readFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .noBuiltInDisplay:
            "Maclum could not find the built-in display."
        case .displayServicesUnavailable:
            "macOS did not provide its private brightness service."
        case let .readFailed(status):
            "macOS could not read built-in brightness (DisplayServices status \(status))."
        }
    }
}

public protocol BuiltInBrightnessReading: AnyObject {
    func read() throws -> Double
}

public final class DisplayServicesBrightnessReader: BuiltInBrightnessReading {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private let getBrightness: GetBrightness?

    public init() {
        let framework = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(framework, RTLD_LAZY),
              let symbol = dlsym(handle, "DisplayServicesGetBrightness")
        else {
            getBrightness = nil
            return
        }
        getBrightness = unsafeBitCast(symbol, to: GetBrightness.self)
    }

    public func read() throws -> Double {
        guard let getBrightness else { throw BuiltInBrightnessError.displayServicesUnavailable }
        let display = try builtInDisplayID()
        var brightness: Float = 0
        let status = getBrightness(display, &brightness)
        guard status == 0 else { throw BuiltInBrightnessError.readFailed(status) }
        return Double(brightness).clamped(to: 0...1)
    }

    private func builtInDisplayID() throws -> CGDirectDisplayID {
        var displays = Array(repeating: CGDirectDisplayID(), count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(UInt32(displays.count), &displays, &count) == .success,
              let display = displays.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 })
        else {
            throw BuiltInBrightnessError.noBuiltInDisplay
        }
        return display
    }
}
