import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var client = LibreLinkClient.shared
    @State private var password: String = ""
    @State private var showPassword: Bool = false
    @State private var savedMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("LibreLink HUD Settings")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // MARK: Credentials
                    SettingsSection("LibreLinkUp Credentials") {
                        VStack(alignment: .leading, spacing: 8) {
                            SettingsLabel("Email")
                            TextField("Email", text: $settings.email)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            SettingsLabel("Password")
                            HStack {
                                if showPassword {
                                    TextField("Password", text: $password)
                                        .textFieldStyle(.roundedBorder)
                                } else {
                                    SecureField("Password", text: $password)
                                        .textFieldStyle(.roundedBorder)
                                }
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            SettingsLabel("Region")
                            Picker("", selection: $settings.region) {
                                Text("Europe").tag("eu")
                                Text("United States").tag("us")
                                Text("Germany").tag("de")
                                Text("France").tag("fr")
                                Text("Japan").tag("jp")
                                Text("Asia Pacific").tag("ap")
                                Text("Australia").tag("au")
                                Text("UAE").tag("ae")
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text("Region auto-corrects if the server redirects you.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // MARK: General
                    SettingsSection("General") {
                        Toggle("Launch at Login", isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { settings.launchAtLogin = $0 }
                        ))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // MARK: Display
                    SettingsSection("Display") {
                        Toggle("Use mmol/L", isOn: $settings.useMmol)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack {
                            Text("Polling Interval")
                            Spacer()
                            Picker("", selection: $settings.pollingInterval) {
                                Text("1 min").tag(60.0)
                                Text("2 min").tag(120.0)
                                Text("3 min").tag(180.0)
                                Text("5 min").tag(300.0)
                            }
                            .frame(width: 120)
                        }
                    }

                    // MARK: HUD Appearance
                    SettingsSection("HUD Appearance") {
                        HStack {
                            Text("Transparency")
                            Slider(value: $settings.hudOpacity, in: 1...100, step: 1)
                                .onChange(of: settings.hudOpacity) { opacity in
                                    HUDPanelController.shared.updateOpacity(opacity)
                                }
                            Text("\(Int(settings.hudOpacity))%")
                                .frame(width: 40, alignment: .trailing)
                                .monospacedDigit()
                        }

                        Text("Drag the HUD edges to resize it. Size is remembered.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // MARK: Thresholds
                    SettingsSection("Thresholds (mg/dL)") {
                        HStack {
                            Text("Low")
                            Spacer()
                            TextField("Low", value: $settings.lowThreshold, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("High")
                            Spacer()
                            TextField("High", value: $settings.highThreshold, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Buttons
            HStack {
                if let msg = savedMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
                Button("Save & Connect") {
                    settings.password = password
                    client.logout()
                    client.startPolling()
                    savedMessage = "Saved! Connecting..."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        savedMessage = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(settings.email.isEmpty || password.isEmpty)
            }
            .padding()
        }
        .frame(width: 420, height: 560)
        .onAppear {
            password = settings.password
        }
    }
}

// MARK: - Helpers

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

private struct SettingsLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.primary)
    }
}

// MARK: - Settings Window Controller

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func showWindow() {
        // LSUIElement apps need explicit activation to accept keyboard input
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)

        if let window = window {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LibreLink HUD Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(hostingView)

        self.window = window
    }
}
