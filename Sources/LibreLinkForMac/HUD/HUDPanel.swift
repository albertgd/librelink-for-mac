import SwiftUI
import AppKit

// MARK: - HUD Panel (NSPanel-based floating window)

final class HUDPanelController: ObservableObject {
    static let shared = HUDPanelController()

    private var panel: NSPanel?

    func show() {
        if let panel = panel {
            panel.orderFront(nil)
            return
        }

        let hudView = HUDContentView()
        let hostingView = NSHostingView(rootView: hudView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 220),
            styleMask: [.titled, .closable, .nonactivatingPanel, .hudWindow, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.title = "Glucose HUD"
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false

        // Position in top-right corner
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 300
            let y = screenFrame.maxY - 240
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }
}

// MARK: - HUD Content View

struct HUDContentView: View {
    @ObservedObject var client = LibreLinkClient.shared
    @ObservedObject var settings = SettingsStore.shared

    var body: some View {
        VStack(spacing: 8) {
            // Current glucose
            if let glucose = client.currentGlucose {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(formattedGlucose(glucose.value))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(glucoseColor(glucose.value))

                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: glucose.trendArrow.sfSymbol)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(glucoseColor(glucose.value))

                        Text(settings.useMmol ? "mmol/L" : "mg/dL")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.top, 4)

                // Time since last reading
                if let ts = glucose.timestamp {
                    Text(ts, style: .relative)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            } else {
                Text("---")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 4)
            }

            // Trend graph
            GlucoseGraphView(
                entries: client.graphData,
                lowThreshold: settings.lowThreshold,
                highThreshold: settings.highThreshold,
                useMmol: settings.useMmol
            )
            .frame(height: 90)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 280, height: 220)
    }

    private func formattedGlucose(_ value: Double) -> String {
        if settings.useMmol {
            return String(format: "%.1f", value / 18.0)
        }
        return "\(Int(value))"
    }

    private func glucoseColor(_ value: Double) -> Color {
        switch GlucoseRange.from(value: value) {
        case .low: return .red
        case .normal: return .green
        case .high: return .orange
        }
    }
}
