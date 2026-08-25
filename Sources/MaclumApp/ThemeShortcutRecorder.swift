import AppKit
import MaclumCore
import SwiftUI

struct ThemeShortcutRecorder: View {
	let label: String
	let shortcut: ThemeShortcut?
	let onShortcutChanged: (ThemeShortcut?) -> Void

	@State private var isRecording = false
	@State private var eventMonitor: Any?

	var body: some View {
		Button(isRecording ? "Press shortcut…" : ThemeShortcutFormatter.string(for: shortcut)) {
			isRecording ? stopRecording() : startRecording()
		}
		.buttonStyle(.bordered)
		.font(.caption.monospaced())
		.help("Click to record a global hotkey. Use Command, Control, or Option; press Delete to clear it.")
		.accessibilityLabel(label)
		.onDisappear(perform: stopRecording)
	}

	private func startRecording() {
		stopRecording()
		isRecording = true
		eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
			if event.keyCode == 53 {
				stopRecording()
				return nil
			}
			if event.keyCode == 51 {
				onShortcutChanged(nil)
				stopRecording()
				return nil
			}

			let shortcut = ThemeShortcut(
				keyCode: event.keyCode,
				modifiers: modifiers(for: event.modifierFlags)
			)
			guard shortcut.isValidForGlobalRegistration else {
				NSSound.beep()
				return nil
			}

			onShortcutChanged(shortcut)
			stopRecording()
			return nil
		}
	}

	private func stopRecording() {
		if let eventMonitor {
			NSEvent.removeMonitor(eventMonitor)
			self.eventMonitor = nil
		}
		isRecording = false
	}

	private func modifiers(for flags: NSEvent.ModifierFlags) -> ThemeShortcutModifiers {
		var modifiers: ThemeShortcutModifiers = []
		if flags.contains(.command) { modifiers.insert(.command) }
		if flags.contains(.control) { modifiers.insert(.control) }
		if flags.contains(.option) { modifiers.insert(.option) }
		if flags.contains(.shift) { modifiers.insert(.shift) }
		return modifiers
	}
}

private enum ThemeShortcutFormatter {
	static func string(for shortcut: ThemeShortcut?) -> String {
		guard let shortcut else { return "Set hotkey" }

		var result = ""
		if shortcut.modifiers.contains(.control) { result += "⌃" }
		if shortcut.modifiers.contains(.option) { result += "⌥" }
		if shortcut.modifiers.contains(.shift) { result += "⇧" }
		if shortcut.modifiers.contains(.command) { result += "⌘" }
		return result + keyName(for: shortcut.keyCode)
	}

	private static func keyName(for keyCode: UInt16) -> String {
		let names: [UInt16: String] = [
			0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
			11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
			20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
			29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
			38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
			47: ".", 48: "⇥", 49: "Space", 123: "←", 124: "→", 125: "↓", 126: "↑",
		]
		return names[keyCode] ?? "Key \(keyCode)"
	}
}
