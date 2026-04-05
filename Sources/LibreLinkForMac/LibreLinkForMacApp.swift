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
            HStack(spacing: 4) {
                Image(systemName: MenuBarLabel.image(glucose: client.currentGlucose))
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
        // Start polling if credentials exist
        if SettingsStore.shared.hasCredentials {
            LibreLinkClient.shared.startPolling()
        }
    }
}
