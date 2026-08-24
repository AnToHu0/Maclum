import AppKit
import MaclumCore
import SwiftUI

struct MaclumPanel: View {
    private static let width: CGFloat = 420
    private static let maximumHeight: CGFloat = 640

    @ObservedObject var model: BrightnessAppModel
    @State private var showsDisconnectedDisplays = false
    @State private var contentHeight: CGFloat = 320

    var body: some View {
        ScrollView {
            panelContent
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: PanelContentHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                }
        }
        .frame(width: Self.width, height: min(contentHeight, Self.maximumHeight))
        .onPreferenceChange(PanelContentHeightKey.self) { contentHeight = $0 }
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Maclum", systemImage: "sun.max")
                    .font(.headline)
                Spacer()
                Text(macBrightnessLabel)
                    .foregroundStyle(.secondary)
            }

            Text("Low / Mid / High correspond to Mac brightness 0% / 50% / 100%.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.m1ddcIsInstalled {
                displayProfiles
            } else {
                missingDependency
            }

            statusMessage

            Divider()

            Text("For reliable syncing, turn off the monitor’s own automatic brightness.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Refresh displays") {
                    model.refreshDisplays()
                }
                Spacer()
                Button("Quit Maclum") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var displayProfiles: some View {
        if model.activeProfiles.isEmpty {
            Label("No DDC/CI display found", systemImage: "display.trianglebadge.exclamationmark")
                .foregroundStyle(.secondary)
        } else {
            ForEach(model.activeProfiles) { profile in
                DisplayProfileRow(
                    profile: profile,
                    displayBrightness: model.displayBrightnesses[profile.id],
                    isConnected: true,
                    onPreviewBegan: { anchor in
                        model.beginPreview(for: profile.id, anchor: anchor)
                    },
                    onPreviewChanged: { anchor, value in
                        model.previewCurve(for: profile.id, anchor: anchor, at: value)
                    },
                    onPreviewEnded: { anchor in
                        model.endPreview(for: profile.id, anchor: anchor)
                    }
                )
            }
        }

        if !model.inactiveProfiles.isEmpty {
            Toggle("Show disconnected displays", isOn: $showsDisconnectedDisplays)
                .font(.caption)

            if showsDisconnectedDisplays {
                ForEach(model.inactiveProfiles) { profile in
                    DisplayProfileRow(
                        profile: profile,
                        displayBrightness: nil,
                        isConnected: false,
                        onPreviewBegan: { _ in },
                        onPreviewChanged: { _, _ in },
                        onPreviewEnded: { _ in },
                        onDelete: {
                            model.removeProfile(id: profile.id)
                        }
                    )
                }
            }
        }
    }

    private var missingDependency: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("m1ddc is required to control DDC/CI displays.", systemImage: "wrench.and.screwdriver")
            HStack {
                Button("Copy install command", action: model.copyInstallCommand)
                Text(M1DDCClient.installCommand)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            Text("Paste the command into Terminal. Homebrew may ask for your password; Maclum never installs software silently.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var macBrightnessLabel: String {
        guard let sourceBrightness = model.sourceBrightness else { return "Mac brightness unavailable" }
        return "Mac: \(Int((sourceBrightness * 100).rounded()))%"
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch model.status {
        case .idle:
            EmptyView()
        case let .error(message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private enum PanelContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct DisplayProfileRow: View {
    let profile: DisplayProfile
    let displayBrightness: Int?
    let isConnected: Bool
    let onPreviewBegan: (CurveAnchor) -> Void
    let onPreviewChanged: (CurveAnchor, Int) -> Void
    let onPreviewEnded: (CurveAnchor) -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(profile.name, systemImage: "display")
                    .font(.headline)
                Spacer()
                Text(displayBrightnessLabel)
                    .foregroundStyle(.secondary)
            }

            CurveTrack(
                curve: profile.curve,
                onPreviewBegan: onPreviewBegan,
                onPreviewChanged: onPreviewChanged,
                onPreviewEnded: onPreviewEnded
            )
            .frame(height: 92)
            .disabled(!isConnected)

            if let onDelete {
                HStack {
                    Spacer()
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete saved profile")
                    .accessibilityLabel("Delete saved profile for \(profile.name)")
                }
                .padding(.top, -4)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .opacity(isConnected ? 1 : 0.65)
    }

    private var displayBrightnessLabel: String {
        guard isConnected else { return "Not connected" }
        guard let displayBrightness else { return "Display brightness unavailable" }
        return "Display: \(displayBrightness)%"
    }
}

private struct CurveTrack: View {
    let curve: BrightnessCurve
    let onPreviewBegan: (CurveAnchor) -> Void
    let onPreviewChanged: (CurveAnchor, Int) -> Void
    let onPreviewEnded: (CurveAnchor) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width - 28, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 6)
                    .padding(.horizontal, 14)

                ForEach(CurveAnchor.allCases, id: \.self) { anchor in
                    CurveThumb(
                        anchor: anchor,
                        value: value(for: anchor),
                        onDragStarted: {
                            onPreviewBegan(anchor)
                        },
                        onDrag: { location in
                            let normalized = ((location - 14) / width).clamped(to: 0...1)
                            onPreviewChanged(anchor, Int((normalized * 100).rounded()))
                        },
                        onDragEnded: {
                            onPreviewEnded(anchor)
                        },
                        onAdjust: { value in
                            onPreviewBegan(anchor)
                            onPreviewChanged(anchor, value)
                            onPreviewEnded(anchor)
                        }
                    )
                    .position(x: 14 + (width * CGFloat(value(for: anchor)) / 100), y: geometry.size.height / 2)
                }
            }
        }
        .coordinateSpace(name: "curve-track")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Brightness curve")
    }

    private func value(for anchor: CurveAnchor) -> Int {
        switch anchor {
        case .low: curve.low
        case .mid: curve.mid
        case .high: curve.high
        }
    }
}

private struct CurveThumb: View {
    let anchor: CurveAnchor
    let value: Int
    let onDragStarted: () -> Void
    let onDrag: (CGFloat) -> Void
    let onDragEnded: () -> Void
    let onAdjust: (Int) -> Void
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 4) {
            Text(anchor.rawValue.capitalized)
                .font(.caption2.weight(.medium))
            Circle()
                .fill(tint)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(.background, lineWidth: 2))
            Text("\(value)%")
                .font(.caption2.monospacedDigit())
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("curve-track"))
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        onDragStarted()
                    }
                    onDrag(value.location.x)
                }
                .onEnded { _ in
                    isDragging = false
                    onDragEnded()
                }
        )
        .accessibilityLabel("\(anchor.rawValue.capitalized) external brightness")
        .accessibilityValue("\(value) percent")
        .accessibilityAdjustableAction { direction in
            onAdjust(value + (direction == .increment ? 1 : -1))
        }
    }

    private var tint: Color {
        switch anchor {
        case .low: .blue
        case .mid: .orange
        case .high: .yellow
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
