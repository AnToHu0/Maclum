import Foundation
import MaclumCore

@MainActor
protocol SystemAppearanceControlling {
	func currentTheme() throws -> SystemTheme
	func setTheme(_ theme: SystemTheme) throws
}

enum SystemAppearanceError: LocalizedError {
	case automationFailed(String)

	var errorDescription: String? {
		switch self {
		case let .automationFailed(message):
			"Appearance could not be changed. \(message)"
		}
	}
}

@MainActor
final class SystemEventsAppearanceController: SystemAppearanceControlling {
	func currentTheme() throws -> SystemTheme {
		let interfaceStyle = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] as? String
		return interfaceStyle == "Dark" ? .dark : .light
	}

	func setTheme(_ theme: SystemTheme) throws {
		let darkMode = theme == .dark ? "true" : "false"
		let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(darkMode)"
		let process = Process()
		let standardError = Pipe()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
		process.arguments = ["-e", script]
		process.standardError = standardError

		try process.run()
		process.waitUntilExit()
		guard process.terminationStatus == 0 else {
			let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
			let errorMessage = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
			throw SystemAppearanceError.automationFailed(errorMessage?.isEmpty == false ? errorMessage! : "macOS did not allow System Events automation.")
		}
	}
}
