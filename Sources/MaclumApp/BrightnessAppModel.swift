import AppKit
import Combine
import Foundation
import MaclumCore

@MainActor
final class BrightnessAppModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case error(String)
    }

    private struct PreviewTarget: Equatable {
        let displayID: String
        let anchor: CurveAnchor
    }

    private struct DDCProbeResult {
        let displays: [DDCDisplay]
        let brightnesses: [String: Int]
        let unavailableDisplayIDs: Set<String>
    }

    @Published private(set) var settings = MaclumSettings.default
    @Published private(set) var displays: [DDCDisplay] = []
    @Published private(set) var sourceBrightness: Double?
    @Published private(set) var displayBrightnesses: [String: Int] = [:]
	@Published private(set) var currentTheme: SystemTheme = .light
    @Published private(set) var status: Status = .idle

    private let displayReader: any BuiltInBrightnessReading
    private let ddcClient: any DDCControlling
    private lazy var synchronizer = BrightnessSynchronizer(client: ddcClient)
    private let settingsStore: SettingsStore
	private let appearanceController: any SystemAppearanceControlling
    private var pollingTimer: Timer?
    private var previewTarget: PreviewTarget?
    private var settingsWarning: String?
	private var appearanceWarning: String?
	private var shortcutWarning: String?
    private var lastDisplayBrightnessRefresh: Date?
    private var unavailableDisplayIDs: Set<String> = []

    private static let displayBrightnessRefreshInterval: TimeInterval = 2

    convenience init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.init(
            displayReader: DisplayServicesBrightnessReader(),
            ddcClient: M1DDCClient(),
			settingsStore: SettingsStore(fileURL: applicationSupport.appending(path: "Maclum/settings.json")),
			appearanceController: SystemEventsAppearanceController()
        )
    }

    init(
        displayReader: any BuiltInBrightnessReading,
        ddcClient: any DDCControlling,
		settingsStore: SettingsStore,
		appearanceController: any SystemAppearanceControlling = SystemEventsAppearanceController()
    ) {
        self.displayReader = displayReader
        self.ddcClient = ddcClient
        self.settingsStore = settingsStore
		self.appearanceController = appearanceController
    }

    var m1ddcIsInstalled: Bool { ddcClient.isInstalled }
    var activeProfiles: [DisplayProfile] { settings.activeProfiles(for: displays) }
    var inactiveProfiles: [DisplayProfile] {
        settings.inactiveProfiles(for: displays).filter { !unavailableDisplayIDs.contains($0.id) }
    }
	var manualThemeShortcut: ThemeShortcut? { settings.theme.manualToggleShortcut }
	var resumeAutomaticThemeShortcut: ThemeShortcut? { settings.theme.resumeAutomaticShortcut }
	var automaticThemeThreshold: Int { settings.theme.automaticThreshold }
	var isAutomaticThemeSwitchingEnabled: Bool { settings.theme.isAutomaticSwitchingEnabled }
	var onThemeShortcutsChanged: (() -> Void)?

    func start() {
        loadSettings()
		refreshCurrentTheme()
        refreshDisplays()
        synchronizeFromBuiltInDisplay()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.synchronizeFromBuiltInDisplay()
            }
        }
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func refreshDisplays() {
        guard m1ddcIsInstalled else {
            displays = []
            unavailableDisplayIDs = []
            status = .error("m1ddc is not installed.")
            return
        }

        do {
            let probeResult = probeDisplays(try ddcClient.displays())
            displays = probeResult.displays
            displayBrightnesses = probeResult.brightnesses
            unavailableDisplayIDs = probeResult.unavailableDisplayIDs
            lastDisplayBrightnessRefresh = Date()
            if settings.synchronizeProfiles(with: displays) {
                persistSettings()
            }
            showIdleStatus()
        } catch {
            displays = []
            displayBrightnesses = [:]
            unavailableDisplayIDs = []
            status = .error(error.localizedDescription)
        }
    }

    func beginPreview(for displayID: String, anchor: CurveAnchor) {
        previewTarget = PreviewTarget(displayID: displayID, anchor: anchor)
    }

    func previewCurve(for displayID: String, anchor: CurveAnchor, at value: Int) {
        guard let profile = settings.profiles.first(where: { $0.id == displayID }) else { return }
        let curve = profile.curve.setting(anchor, to: value)
        settings.setCurve(curve, for: displayID)
        persistSettings()

        do {
            switch try synchronizer.preview(luminance: curveValue(for: anchor, in: curve), displayID: displayID) {
            case .sent, .unchanged:
                break
            }
        } catch {
            status = .error("\(profile.name): \(error.localizedDescription)")
        }
        refreshDisplayBrightnesses(force: true)
    }

    func endPreview(for displayID: String, anchor: CurveAnchor) {
        guard previewTarget == PreviewTarget(displayID: displayID, anchor: anchor) else { return }
        previewTarget = nil
        synchronizeFromBuiltInDisplay()
    }

    func copyInstallCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(M1DDCClient.installCommand, forType: .string)
        showIdleStatus()
    }

    func removeProfile(id: String) {
        guard !displays.contains(where: { $0.id == id }), settings.removeProfile(id: id) else { return }
        displayBrightnesses.removeValue(forKey: id)
        persistSettings()
        showIdleStatus()
    }

	func setTheme(_ theme: SystemTheme) {
		do {
			try appearanceController.setTheme(theme)
			currentTheme = theme
			appearanceWarning = nil
			setAutomaticThemeSwitchingEnabled(false)
			showIdleStatus()
		} catch {
			setAppearanceWarning(error)
		}
	}

	func toggleTheme() {
		do {
			currentTheme = try appearanceController.currentTheme()
			setTheme(currentTheme.toggled)
		} catch {
			setAppearanceWarning(error)
		}
	}

	func performThemeShortcut(_ action: ThemeShortcutAction) {
		switch action {
		case .manualToggle:
			toggleTheme()
		case .resumeAutomatic:
			resumeAutomaticTheme()
		}
	}

	func resumeAutomaticTheme() {
		setAutomaticThemeSwitchingEnabled(true)
		synchronizeTheme(using: sourceBrightness)
	}

	func setAutomaticThemeSwitchingEnabled(_ isEnabled: Bool) {
		guard settings.theme.isAutomaticSwitchingEnabled != isEnabled else { return }
		settings.theme.isAutomaticSwitchingEnabled = isEnabled
		persistSettings()
		onThemeShortcutsChanged?()
		if isEnabled {
			synchronizeTheme(using: sourceBrightness)
		}
		showIdleStatus()
	}

	func setAutomaticThemeThreshold(_ threshold: Int) {
		let clampedThreshold = min(max(threshold, 0), 100)
		guard settings.theme.automaticThreshold != clampedThreshold else { return }
		settings.theme.automaticThreshold = clampedThreshold
		persistSettings()
		if settings.theme.isAutomaticSwitchingEnabled {
			synchronizeTheme(using: sourceBrightness)
		}
		showIdleStatus()
	}

	func setThemeShortcut(_ shortcut: ThemeShortcut?, for action: ThemeShortcutAction) {
		let previousSettings = settings.theme
		settings.theme.setShortcut(shortcut, for: action)
		guard settings.theme != previousSettings else { return }
		persistSettings()
		onThemeShortcutsChanged?()
		showIdleStatus()
	}

	func setShortcutWarning(_ warning: String?) {
		shortcutWarning = warning
		showIdleStatus()
	}

    func synchronizeFromBuiltInDisplay() {
        guard previewTarget == nil else { return }

        do {
            let source = try displayReader.read()
            sourceBrightness = source
			synchronizeTheme(using: source)
            let profiles = activeProfiles
            guard !profiles.isEmpty else {
                showIdleStatus()
                return
            }

            var errors: [String] = []
            for profile in profiles {
                do {
                    switch try synchronizer.apply(
                        sourceBrightness: source,
                        curve: profile.curve,
                        displayID: profile.id
                    ) {
                    case .sent, .unchanged:
                        break
                    }
                } catch {
                    errors.append("\(profile.name): \(error.localizedDescription)")
                }
            }

            if !errors.isEmpty {
                status = .error(errors.joined(separator: "\n"))
            }
            refreshDisplayBrightnesses()
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func loadSettings() {
        do {
            settings = try settingsStore.load()
        } catch {
            settings = .default
            settingsWarning = "Settings could not be read; defaults are in use. \(error.localizedDescription)"
            showIdleStatus()
        }
    }

    private func persistSettings() {
        do {
            try settingsStore.save(settings)
            settingsWarning = nil
        } catch {
            settingsWarning = "Settings could not be saved. \(error.localizedDescription)"
        }
    }

    private func showIdleStatus() {
		status = settingsWarning.map(Status.error) ?? appearanceWarning.map(Status.error) ?? shortcutWarning.map(Status.error) ?? .idle
	}

	private func refreshCurrentTheme() {
		do {
			currentTheme = try appearanceController.currentTheme()
			appearanceWarning = nil
			showIdleStatus()
		} catch {
			setAppearanceWarning(error)
		}
	}

	private func synchronizeTheme(using brightness: Double?) {
		guard settings.theme.isAutomaticSwitchingEnabled, let brightness else { return }

		do {
			currentTheme = try appearanceController.currentTheme()
			let targetTheme = settings.theme.automaticTheme(for: brightness, currentTheme: currentTheme)
			guard targetTheme != currentTheme else {
				appearanceWarning = nil
				showIdleStatus()
				return
			}
			try appearanceController.setTheme(targetTheme)
			currentTheme = targetTheme
			appearanceWarning = nil
			showIdleStatus()
		} catch {
			setAppearanceWarning(error)
		}
	}

	private func setAppearanceWarning(_ error: Error) {
		appearanceWarning = "Appearance: \(error.localizedDescription)"
		showIdleStatus()
    }

    private func probeDisplays(_ candidates: [DDCDisplay]) -> DDCProbeResult {
        var supportedDisplays: [DDCDisplay] = []
        var brightnesses: [String: Int] = [:]
        var unavailableDisplayIDs: Set<String> = []

        for display in candidates {
            do {
                brightnesses[display.id] = try ddcClient.luminance(displayID: display.id)
                supportedDisplays.append(display)
            } catch {
                unavailableDisplayIDs.insert(display.id)
            }
        }

        return DDCProbeResult(
            displays: supportedDisplays,
            brightnesses: brightnesses,
            unavailableDisplayIDs: unavailableDisplayIDs
        )
    }

    private func refreshDisplayBrightnesses(force: Bool = false) {
        let now = Date()
        guard force || lastDisplayBrightnessRefresh.map({ now.timeIntervalSince($0) >= Self.displayBrightnessRefreshInterval }) != false else {
            return
        }
        lastDisplayBrightnessRefresh = now

        var updatedBrightnesses: [String: Int] = [:]
        var errors: [String] = []
        for profile in activeProfiles {
            do {
                updatedBrightnesses[profile.id] = try ddcClient.luminance(displayID: profile.id)
            } catch {
                errors.append("\(profile.name): \(error.localizedDescription)")
            }
        }
        displayBrightnesses = updatedBrightnesses

        if !errors.isEmpty {
            status = .error(errors.joined(separator: "\n"))
        }
    }

    private func curveValue(for anchor: CurveAnchor, in curve: BrightnessCurve) -> Int {
        switch anchor {
        case .low: curve.low
        case .mid: curve.mid
        case .high: curve.high
        }
    }
}
