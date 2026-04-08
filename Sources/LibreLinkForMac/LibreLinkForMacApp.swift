import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard SettingsStore.shared.hasCredentials, SettingsStore.shared.hudVisible else { return }
        HUDPanelController.shared.show()
    }
}

@main
struct LibreLinkForMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var client = LibreLinkClient.shared
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            HStack(spacing: 2) {
                if client.currentGlucose != nil {
                    Image(systemName: MenuBarLabel.image(glucose: client.currentGlucose))
                }
                Text(MenuBarLabel.text(glucose: client.currentGlucose, settings: settings))
            }
        }
        .menuBarExtraStyle(.window)
        .onChange(of: settings.hudVisible) { visible in
            if visible {
                HUDPanelController.shared.show()
            } else {
                HUDPanelController.shared.hide()
            }
        }
    }

    init() {
        if SettingsStore.shared.hasCredentials {
            SettingsStore.shared.hudVisible = true
            LibreLinkClient.shared.startPolling()
        } else {
            SettingsStore.shared.hudVisible = false
            // First launch — open Settings so the user can enter credentials
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.activate(ignoringOtherApps: true)
                SettingsWindowController.shared.showWindow()
            }
        }
    }
}
