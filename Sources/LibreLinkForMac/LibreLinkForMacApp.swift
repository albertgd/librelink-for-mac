import SwiftUI
import Combine

@main
struct LibreLinkForMacApp: App {
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
        // Panel always starts hidden regardless of last saved state
        SettingsStore.shared.hudVisible = false

        if SettingsStore.shared.hasCredentials {
            LibreLinkClient.shared.startPolling()
        } else {
            // First launch — open Settings so the user can enter credentials
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.activate(ignoringOtherApps: true)
                SettingsWindowController.shared.showWindow()
            }
        }
    }
}
