import Carbon
import Foundation
import MaclumCore

@MainActor
final class ThemeHotKeyMonitor {
	private static let signature: OSType = 0x4D41434C // MACL
	private static let manualToggleID: UInt32 = 1
	private static let resumeAutomaticID: UInt32 = 2

	private var eventHandler: EventHandlerRef?
	private var registeredHotKeys: [EventHotKeyRef] = []
	private var actions: [UInt32: () -> Void] = [:]

	init() {
		var eventType = EventTypeSpec(
			eventClass: OSType(kEventClassKeyboard),
			eventKind: UInt32(kEventHotKeyPressed)
		)
		let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
		InstallEventHandler(
			GetApplicationEventTarget(),
			Self.handleEvent,
			1,
			&eventType,
			context,
			&eventHandler
		)
	}

	func stop() {
		for hotKey in registeredHotKeys {
			UnregisterEventHotKey(hotKey)
		}
		registeredHotKeys.removeAll()
		if let eventHandler {
			RemoveEventHandler(eventHandler)
			self.eventHandler = nil
		}
	}

	func configure(
		manualToggle: ThemeShortcut?,
		resumeAutomatic: ThemeShortcut?,
		onManualToggle: @escaping () -> Void,
		onResumeAutomatic: @escaping () -> Void
	) -> String? {
		unregisterAll()
		actions = [:]

		var errors: [String] = []
		for (shortcut, identifier, action, label) in [
			(manualToggle, Self.manualToggleID, onManualToggle, "Theme toggle"),
			(resumeAutomatic, Self.resumeAutomaticID, onResumeAutomatic, "Automatic theme"),
		] {
			do {
				try register(shortcut, identifier: identifier, action: action)
			} catch {
				errors.append("\(label): \(error.localizedDescription)")
			}
		}

		if errors.isEmpty {
			return nil
		}
		return "Some theme hotkeys could not be registered. \(errors.joined(separator: "\n"))"
	}

	private func register(_ shortcut: ThemeShortcut?, identifier: UInt32, action: @escaping () -> Void) throws {
		guard let shortcut else { return }

		var hotKey: EventHotKeyRef?
		let status = RegisterEventHotKey(
			UInt32(shortcut.keyCode),
			carbonModifiers(for: shortcut.modifiers),
			EventHotKeyID(signature: Self.signature, id: identifier),
			GetApplicationEventTarget(),
			0,
			&hotKey
		)
		guard status == noErr, let hotKey else {
			throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
		}
		registeredHotKeys.append(hotKey)
		actions[identifier] = action
	}

	private func unregisterAll() {
		for hotKey in registeredHotKeys {
			UnregisterEventHotKey(hotKey)
		}
		registeredHotKeys.removeAll()
	}

	private func carbonModifiers(for modifiers: ThemeShortcutModifiers) -> UInt32 {
		var carbonModifiers: UInt32 = 0
		if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
		if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
		if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
		if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
		return carbonModifiers
	}

	private static let handleEvent: EventHandlerUPP = { _, event, userData in
		guard let event, let userData else { return noErr }
		var hotKeyID = EventHotKeyID()
		let status = GetEventParameter(
			event,
			EventParamName(kEventParamDirectObject),
			EventParamType(typeEventHotKeyID),
			nil,
			MemoryLayout<EventHotKeyID>.size,
			nil,
			&hotKeyID
		)
		guard status == noErr, hotKeyID.signature == ThemeHotKeyMonitor.signature else { return noErr }

		let monitor = Unmanaged<ThemeHotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
		Task { @MainActor in
			monitor.actions[hotKeyID.id]?()
		}
		return noErr
	}
}
