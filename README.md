# LibreLink HUD for Mac

A macOS Menu Bar application that displays real-time glucose data from the LibreLinkUp API. Features an always-on-top floating HUD with a trend graph.

## Features

- **Menu Bar Integration** — Current glucose value and trend arrow always visible in your menu bar
- **Floating HUD** — Always-on-top transparent panel with large glucose display and trend graph (works over full-screen apps)
- **Trend Graph** — Visual history of glucose readings with high/low threshold zones
- **Resizable HUD** — Drag edges to resize, size is remembered between launches
- **Adjustable Transparency** — HUD opacity from 1% to 100%, updates in real time
- **Configurable** — Polling interval (1-5 min), mg/dL or mmol/L, custom thresholds
- **Secure** — Password stored in macOS Keychain, not in plain text
- **Multi-Region** — Supports all LibreLinkUp regions (auto-detected via server redirect)
- **Auto Token Refresh** — Re-authenticates automatically when the token expires
- **Terms of Use Handling** — Automatically accepts LibreView TOU/PP when required

## Requirements

- macOS 13 (Ventura) or later
- A LibreLinkUp account with at least one shared connection

## Install

### Homebrew (recommended)

```bash
brew tap albertgd/tap
brew install --cask librelink-for-mac
```

### Build from source

```bash
git clone https://github.com/albertgd/librelink-for-mac.git
cd librelink-for-mac

# Option A: Build script
./build.sh
open .build/release/LibreLinkForMac.app

# Option B: Make
make
open .build/release/LibreLinkForMac.app

# Option C: Debug run
swift run
```

### Create a DMG installer

```bash
make dmg
# Output: .build/release/LibreLinkForMac.dmg
```

## Setup

1. Launch the app — the **Settings** window opens automatically on first run
2. Enter your **LibreLinkUp email** and **password**
3. Select your **region** (auto-corrects if the server redirects you)
4. Click **Save & Connect**
5. Your glucose appears in the menu bar — click it to toggle the **floating HUD**

## How It Works

The app authenticates with the LibreLinkUp API following the same flow as [GlucoDataHandler](https://github.com/pachi81/GlucoDataHandler):

1. **Login** (`POST /llu/auth/login`) — Handles region redirects and Terms of Use acceptance
2. **Get Connections** (`GET /llu/connections`) — Finds your linked patient
3. **Get Graph Data** (`GET /llu/connections/{patientId}/graph`) — Fetches current glucose + history

The token is automatically refreshed when it expires. Data is polled at your configured interval (default: 1 minute).

## Trend Arrows

| Value | Meaning | Icon |
|-------|---------|------|
| 1 | Falling Quickly | arrow.down |
| 2 | Falling | arrow.down.right |
| 3 | Stable | arrow.right |
| 4 | Rising | arrow.up.right |
| 5 | Rising Quickly | arrow.up |

## CI/CD

The project includes a GitHub Action that automatically builds and creates releases:

- **On tag push** (`v*`): Builds the app, creates a DMG and ZIP, and publishes a GitHub Release
- **Manual trigger**: Use `workflow_dispatch` to build on demand

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Project Structure

```
Sources/LibreLinkForMac/
├── LibreLinkForMacApp.swift    # App entry point + menu bar setup
├── Info.plist                  # App metadata (LSUIElement for menu bar)
├── API/
│   └── LibreLinkClient.swift   # LibreLinkUp API client (auth, connections, glucose)
├── Models/
│   ├── GlucoseModels.swift     # API response models, trend arrows, SHA-256 helper
│   └── SettingsStore.swift     # Persistent settings + Keychain helper
├── Views/
│   ├── MenuBarView.swift       # Menu bar dropdown content
│   ├── SettingsView.swift      # Settings window
│   └── GlucoseGraphView.swift  # Trend graph visualization
└── HUD/
    └── HUDPanel.swift          # NSPanel-based floating HUD
```

## Author

**Albert Garcia Diaz**

- GitHub: [@albertgd](https://github.com/albertgd)
- X: [@albertgd](https://x.com/albertgd)
- LinkedIn: [albertgd](https://linkedin.com/in/albertgd)

## License

MIT
