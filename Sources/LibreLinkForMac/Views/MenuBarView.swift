import SwiftUI

struct MenuBarView: View {
    @ObservedObject var client = LibreLinkClient.shared
    @ObservedObject var settings = SettingsStore.shared
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            if let glucose = client.currentGlucose {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedGlucose(glucose.value))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(glucoseColor(glucose.value))
                        Text(glucose.trendArrow.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: glucose.trendArrow.sfSymbol)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(glucoseColor(glucose.value))

                    Spacer()

                    if let ts = glucose.timestamp {
                        Text(ts, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            } else if client.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
            } else {
                Text("No glucose data")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            if let error = client.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
            }

            if !client.connectionName.isEmpty {
                Text("Patient: \(client.connectionName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
            }

            Divider()

            // Actions
            Button {
                settings.hudVisible.toggle()
                if settings.hudVisible {
                    HUDPanelController.shared.show()
                } else {
                    HUDPanelController.shared.hide()
                }
            } label: {
                Label(
                    settings.hudVisible ? "Hide HUD" : "Show HUD",
                    systemImage: settings.hudVisible ? "eye.slash" : "eye"
                )
            }
            .padding(.horizontal, 8)

            Button {
                client.fetchGlucoseData()
            } label: {
                Label("Refresh Now", systemImage: "arrow.clockwise")
            }
            .padding(.horizontal, 8)

            Button {
                showSettings = true
                NSApp.activate(ignoringOtherApps: true)
                SettingsWindowController.shared.showWindow()
            } label: {
                Label("Settings...", systemImage: "gear")
            }
            .padding(.horizontal, 8)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 260)
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

// MARK: - Menu Bar Label

struct MenuBarLabel {
    static func text(glucose: GlucoseEntry?, settings: SettingsStore) -> String {
        guard let glucose = glucose else { return "---" }
        let value: String
        if settings.useMmol {
            value = String(format: "%.1f", glucose.value / 18.0)
        } else {
            value = "\(Int(glucose.value))"
        }
        return value
    }

    static func image(glucose: GlucoseEntry?) -> String {
        glucose?.trendArrow.sfSymbol ?? "questionmark"
    }
}
