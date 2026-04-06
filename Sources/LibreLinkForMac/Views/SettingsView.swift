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

            Form {
                Section("LibreLinkUp Credentials") {
                    TextField("Email", text: $settings.email)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.leading)

                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.leading)
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

                    Picker("Region", selection: $settings.region) {
                        Text("Europe").tag("eu")
                        Text("United States").tag("us")
                        Text("Germany").tag("de")
                        Text("France").tag("fr")
                        Text("Japan").tag("jp")
                        Text("Asia Pacific").tag("ap")
                        Text("Australia").tag("au")
                        Text("UAE").tag("ae")
                    }

                    Text("Region auto-corrects if the server redirects you.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Section("Display") {
                    Toggle("Use mmol/L", isOn: $settings.useMmol)

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

                Section("HUD Appearance") {
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

                Section("Thresholds (mg/dL)") {
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
            .formStyle(.grouped)
            .padding(.horizontal)

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
