import Foundation

public enum SystemTheme: String, Codable, CaseIterable, Equatable, Sendable {
	case light
	case dark

	public var toggled: SystemTheme {
		self == .light ? .dark : .light
	}
}

public struct ThemeShortcutModifiers: OptionSet, Codable, Equatable, Sendable {
	public let rawValue: UInt32

	public init(rawValue: UInt32) {
		self.rawValue = rawValue
	}

	public static let command = ThemeShortcutModifiers(rawValue: 1 << 0)
	public static let control = ThemeShortcutModifiers(rawValue: 1 << 1)
	public static let option = ThemeShortcutModifiers(rawValue: 1 << 2)
	public static let shift = ThemeShortcutModifiers(rawValue: 1 << 3)

	public static let requiredForGlobalShortcut: ThemeShortcutModifiers = [.command, .control, .option]
}

public struct ThemeShortcut: Codable, Equatable, Sendable {
	public let keyCode: UInt16
	public let modifiers: ThemeShortcutModifiers

	public init(keyCode: UInt16, modifiers: ThemeShortcutModifiers) {
		self.keyCode = keyCode
		self.modifiers = modifiers
	}

	public var isValidForGlobalRegistration: Bool {
		!modifiers.intersection(.requiredForGlobalShortcut).isEmpty
	}
}

public enum ThemeShortcutAction: CaseIterable, Equatable, Sendable {
	case manualToggle
	case resumeAutomatic
}

public struct ThemeSettings: Codable, Equatable, Sendable {
	public var isAutomaticSwitchingEnabled: Bool
	public var automaticThreshold: Int
	public private(set) var manualToggleShortcut: ThemeShortcut?
	public private(set) var resumeAutomaticShortcut: ThemeShortcut?

	public init(
		isAutomaticSwitchingEnabled: Bool = false,
		automaticThreshold: Int = 35,
		manualToggleShortcut: ThemeShortcut? = nil,
		resumeAutomaticShortcut: ThemeShortcut? = nil
	) {
		self.isAutomaticSwitchingEnabled = isAutomaticSwitchingEnabled
		self.automaticThreshold = automaticThreshold.clamped(to: 0...100)
		self.manualToggleShortcut = manualToggleShortcut?.isValidForGlobalRegistration == true ? manualToggleShortcut : nil
		self.resumeAutomaticShortcut = resumeAutomaticShortcut?.isValidForGlobalRegistration == true ? resumeAutomaticShortcut : nil
		if self.manualToggleShortcut == self.resumeAutomaticShortcut, self.manualToggleShortcut != nil {
			self.resumeAutomaticShortcut = nil
		}
	}

	public static let `default` = ThemeSettings()

	public func automaticTheme(for brightness: Double, currentTheme: SystemTheme) -> SystemTheme {
		let brightnessPercent = brightness.clamped(to: 0...1) * 100
		let darkBoundary = Double(max(automaticThreshold - 2, 0))
		let lightBoundary = Double(min(automaticThreshold + 2, 100))

		if brightnessPercent <= darkBoundary {
			return .dark
		}
		if brightnessPercent >= lightBoundary {
			return .light
		}
		return currentTheme
	}

	public mutating func setShortcut(_ shortcut: ThemeShortcut?, for action: ThemeShortcutAction) {
		guard shortcut?.isValidForGlobalRegistration != false else { return }

		switch action {
		case .manualToggle:
			manualToggleShortcut = shortcut
			if shortcut != nil, resumeAutomaticShortcut == shortcut {
				resumeAutomaticShortcut = nil
			}
		case .resumeAutomatic:
			resumeAutomaticShortcut = shortcut
			if shortcut != nil, manualToggleShortcut == shortcut {
				manualToggleShortcut = nil
			}
		}
	}
}
