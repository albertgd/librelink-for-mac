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

                    Picker("Region", selection: $settings.regionRaw) {
                        ForEach(LibreLinkRegion.allCases) { region in
                            Text(region.displayName).tag(region.rawValue)
                        }
                    }
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
        .frame(width: 420, height: 480)
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
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LibreLink HUD Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }
}
