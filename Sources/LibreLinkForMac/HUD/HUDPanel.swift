import SwiftUI
import AppKit
import Combine

// MARK: - HUD Panel (NSPanel-based floating window)

final class HUDPanelController: ObservableObject {
    static let shared = HUDPanelController()

    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private let settings = SettingsStore.shared

    func show() {
        if let panel = panel {
            panel.orderFront(nil)
            return
        }

        let hudView = HUDContentView()
        let hostingView = NSHostingView(rootView: hudView)

        let width = settings.hudWidth
        let height = settings.hudHeight

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
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
        panel.titleVisibility = .hidden
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = NSColor.black.withAlphaComponent(settings.hudOpacity / 100.0)
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 200, height: 160)
        panel.maxSize = NSSize(width: 600, height: 500)

        // Position in top-right corner
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - width - 20
            let y = screenFrame.maxY - height - 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        self.panel = panel

        // Save size when user resizes with mouse
        NotificationCenter.default.publisher(for: NSWindow.didResizeNotification, object: panel)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let frame = self?.panel?.frame else { return }
                self?.settings.hudWidth = Double(frame.width)
                self?.settings.hudHeight = Double(frame.height)
            }
            .store(in: &cancellables)
    }

    func updateOpacity(_ opacity: Double) {
        panel?.backgroundColor = NSColor.black.withAlphaComponent(opacity / 100.0)
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
        GeometryReader { geo in
            let isCompact = geo.size.height < 200
            let glucoseSize = max(24, min(52, geo.size.width * 0.18))
            let arrowSize = max(14, min(24, geo.size.width * 0.09))

            VStack(spacing: isCompact ? 4 : 8) {
                // Current glucose
                if let glucose = client.currentGlucose {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(formattedGlucose(glucose.value))
                            .font(.system(size: glucoseSize, weight: .bold, design: .rounded))
                            .foregroundColor(glucoseColor(glucose.value))

                        VStack(alignment: .leading, spacing: 2) {
                            Image(systemName: glucose.trendArrow.sfSymbol)
                                .font(.system(size: arrowSize, weight: .bold))
                                .foregroundColor(glucoseColor(glucose.value))

                            Text(settings.useMmol ? "mmol/L" : "mg/dL")
                                .font(.system(size: max(8, glucoseSize * 0.2)))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.top, isCompact ? 2 : 4)

                    if let ts = glucose.timestamp {
                        Text(ts, style: .relative)
                            .font(.system(size: max(9, glucoseSize * 0.22)))
                            .foregroundColor(.white.opacity(0.5))
                    }
                } else {
                    Text("---")
                        .font(.system(size: glucoseSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.top, isCompact ? 2 : 4)
                }

                // Trend graph
                GlucoseGraphView(
                    entries: client.graphData,
                    lowThreshold: settings.lowThreshold,
                    highThreshold: settings.highThreshold,
                    useMmol: settings.useMmol
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
