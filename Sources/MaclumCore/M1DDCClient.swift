import Foundation

public struct DDCDisplay: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum DDCError: LocalizedError {
    case m1ddcNotInstalled
    case noExternalDisplays
    case commandTimedOut
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .m1ddcNotInstalled:
            "m1ddc is not installed. Install it with: brew install m1ddc"
        case .noExternalDisplays:
            "No DDC/CI external display was found. Check the cable, monitor DDC/CI setting, and connection type."
        case .commandTimedOut:
            "m1ddc did not respond within 2 seconds. Check the monitor connection and DDC/CI setting."
        case let .commandFailed(message):
            message.isEmpty ? "m1ddc could not communicate with the selected display." : message
        }
    }
}

public protocol DDCBrightnessWriting: AnyObject {
    func setLuminance(_ brightness: Int, displayID: String?) throws
}

public protocol DDCControlling: DDCBrightnessWriting {
    var isInstalled: Bool { get }
    func displays() throws -> [DDCDisplay]
    func luminance(displayID: String) throws -> Int
}

public final class M1DDCClient: DDCControlling {
    public static let installCommand = "brew install m1ddc"
    private static let commandTimeout = DispatchTimeInterval.seconds(2)
    private let executableURL: URL?

    public init(fileManager: FileManager = .default) {
        let candidates = [
            "/opt/homebrew/bin/m1ddc",
            "/usr/local/bin/m1ddc",
        ]
        executableURL = candidates
            .map(URL.init(fileURLWithPath:))
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    public var isInstalled: Bool { executableURL != nil }

    public func displays() throws -> [DDCDisplay] {
        let output = try run(["display", "list"])
        let displays = DDCDisplayListParser.parse(output)

        guard !displays.isEmpty else { throw DDCError.noExternalDisplays }
        return displays
    }

    public func setLuminance(_ brightness: Int, displayID: String?) throws {
        var arguments: [String] = []
        if let displayID {
            arguments += ["display", displayID]
        }
        arguments += ["set", "luminance", String(brightness.clamped(to: 0...100))]
        _ = try run(arguments)
    }

    public func luminance(displayID: String) throws -> Int {
        let output = try run(["display", displayID, "get", "luminance"])
        guard let luminance = DDCLuminanceParser.parse(output) else {
            throw DDCError.commandFailed("m1ddc returned an invalid luminance value for the selected display.")
        }
        return luminance
    }

    private func run(_ arguments: [String]) throws -> String {
        guard let executableURL else { throw DDCError.m1ddcNotInstalled }

        let process = Process()
        let output = Pipe()
        let error = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error
        let termination = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in termination.signal() }

        do {
            try process.run()
        } catch {
            throw DDCError.commandFailed(error.localizedDescription)
        }
        guard termination.wait(timeout: .now() + Self.commandTimeout) == .success else {
            process.terminate()
            throw DDCError.commandTimedOut
        }

        let stdout = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let stderr = String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw DDCError.commandFailed((stderr.isEmpty ? stdout : stderr).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return stdout
    }
}

enum DDCLuminanceParser {
    static func parse(_ output: String) -> Int? {
        let value = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              value.allSatisfy(\.isWholeNumber),
              let luminance = Int(value),
              (0...100).contains(luminance)
        else {
            return nil
        }
        return luminance
    }
}

enum DDCDisplayListParser {
    static func parse(_ output: String) -> [DDCDisplay] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap(parseRow)
    }

    private static func parseRow(_ line: Substring) -> DDCDisplay? {
        let text = String(line).trimmingCharacters(in: .whitespaces)
        guard let indexRange = text.range(of: #"^\[[0-9]+\]"#, options: .regularExpression) else { return nil }
        var name = String(text[indexRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard let uuidRange = name.range(of: #"\([0-9A-Fa-f-]+\)$"#, options: .regularExpression) else { return nil }
        let identifier = String(name[uuidRange].dropFirst().dropLast())
        name = String(name[..<uuidRange.lowerBound]).trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty, name != "(null)" else { return nil }
        return DDCDisplay(id: identifier, name: name)
    }
}
