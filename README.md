# LibreLink HUD for Mac

A macOS Menu Bar application that displays real-time glucose data from the LibreLinkUp API. Features an always-on-top floating HUD with a trend graph.

## Features

- **Menu Bar Integration** — Current glucose value and trend arrow always visible in your menu bar
- **Floating HUD** — Always-on-top transparent panel with large glucose display and trend graph (works over full-screen apps)
- **Trend Graph** — Visual history of glucose readings with high/low threshold zones
- **Configurable** — Polling interval (1–5 min), mg/dL or mmol/L, custom thresholds
- **Secure** — Password stored in macOS Keychain, not in plain text
- **Multi-Region** — Supports US, EU, DE, FR, JP, AP, AU, AE LibreLinkUp regions

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ or Swift 5.9+ toolchain
- A LibreLinkUp account with at least one shared connection

## Quick Start

### One-Click Build

```bash
# Clone and build
git clone https://github.com/albertgd/librelink-for-mac.git
cd librelink-for-mac

# Option A: Use the build script
./build.sh

# Option B: Use Make
make

# Run the app
open .build/release/LibreLinkForMac.app
```

### Using Swift directly

```bash
# Debug run (fastest for development)
swift run

# Release build
swift build -c release
```

### Create a DMG installer

```bash
make dmg
# Output: .build/release/LibreLinkForMac.dmg
```

## Setup

1. Launch the app — it appears in your **menu bar** (look for `---` with a `?` icon)
2. Click the menu bar icon → **Settings...**
3. Enter your **LibreLinkUp email**, **password**, and select your **region**
4. Click **Save & Connect**
5. Toggle the **HUD** from the menu bar dropdown

## How It Works

The app authenticates with the LibreLinkUp API using a multi-step process:

1. **Login** → Obtains an auth token
2. **Get Connections** → Finds your linked patient
3. **Get Graph Data** → Fetches current glucose + history

The token is automatically refreshed when it expires. Data is polled at your configured interval (default: 1 minute).

## Trend Arrows

| Arrow | Meaning | Icon |
|-------|---------|------|
| ↓↓ | Falling Quickly | `arrow.down` |
| ↘ | Falling | `arrow.down.right` |
| → | Stable | `arrow.right` |
| ↗ | Rising | `arrow.up.right` |
| ↑↑ | Rising Quickly | `arrow.up` |

## CI/CD

The project includes a GitHub Action that automatically builds and creates releases:

- **On tag push** (`v*`): Builds the app, creates a DMG and ZIP, and publishes a GitHub Release
- **Manual trigger**: Use `workflow_dispatch` to build on demand

To create a release:
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
│   └── LibreLinkClient.swift   # LibreLinkUp API client with auth flow
├── Models/
│   ├── GlucoseModels.swift     # API response models + trend arrows
│   └── SettingsStore.swift     # Persistent settings + Keychain helper
├── Views/
│   ├── MenuBarView.swift       # Menu bar dropdown content
│   ├── SettingsView.swift      # Settings window
│   └── GlucoseGraphView.swift  # Trend graph visualization
└── HUD/
    └── HUDPanel.swift          # NSPanel-based floating HUD
```

## License

MIT
