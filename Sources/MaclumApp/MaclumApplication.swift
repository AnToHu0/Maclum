import AppKit
import MaclumCore
import SwiftUI

@MainActor
private enum AppCompositionRoot {
    static let model = BrightnessAppModel()
}

@main
struct MaclumApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppCompositionRoot.model

    var body: some Scene {
        MenuBarExtra {
            MaclumPanel(model: model)
        } label: {
            Image(nsImage: MaclumStatusIcon.image)
                .accessibilityLabel("Maclum brightness sync")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
private enum MaclumStatusIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 22, height: 18))
        image.lockFocus()

        NSColor.black.setStroke()

        let display = NSBezierPath(roundedRect: NSRect(x: 3, y: 4.5, width: 16, height: 10.5), xRadius: 1.25, yRadius: 1.25)
        display.lineWidth = 1.5
        display.stroke()

        let base = NSBezierPath()
        base.move(to: NSPoint(x: 1.5, y: 2.5))
        base.line(to: NSPoint(x: 20.5, y: 2.5))
        base.lineWidth = 1.5
        base.lineCapStyle = .round
        base.stroke()

        for (start, end) in [
            (NSPoint(x: 11, y: 12.5), NSPoint(x: 11, y: 10.2)),
            (NSPoint(x: 6.2, y: 11.5), NSPoint(x: 8.1, y: 9.6)),
            (NSPoint(x: 15.8, y: 11.5), NSPoint(x: 13.9, y: 9.6)),
        ] {
            let ray = NSBezierPath()
            ray.move(to: start)
            ray.line(to: end)
            ray.lineWidth = 1.2
            ray.lineCapStyle = .round
            ray.stroke()
        }

        image.unlockFocus()
        image.isTemplate = true
        return image
    }()
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        AppCompositionRoot.model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppCompositionRoot.model.stop()
    }
}
