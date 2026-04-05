# Contributing to LibreLink HUD for Mac

Thanks for your interest in contributing! Here's how you can help.

## Getting Started

1. Fork the repo and clone it locally
2. Make sure you have Swift 5.9+ installed (Xcode 15+ or standalone toolchain)
3. Build and run:
   ```bash
   swift run
   ```

## Development

The project uses Swift Package Manager with no external dependencies. The structure is straightforward:

- `API/` — LibreLinkUp API client (auth, connections, glucose fetching)
- `Models/` — Data models and persistent settings
- `Views/` — SwiftUI views for menu bar and settings
- `HUD/` — NSPanel-based floating HUD

### Build Commands

```bash
swift run              # debug run
swift build -c release # release build
make bundle            # create .app bundle
make dmg               # create DMG installer
```

## Submitting Changes

1. Create a feature branch from `main`
2. Make your changes — keep commits focused and descriptive
3. Test that the app builds cleanly: `swift build`
4. Open a pull request against `main`

## Reporting Bugs

Open an issue with:
- macOS version
- Steps to reproduce
- Expected vs actual behavior
- Any error messages from the menu bar dropdown

## Guidelines

- Keep it simple — no heavy external dependencies
- Follow existing code style and structure
- Password/credentials must always go through Keychain, never plain text
- Test with your own LibreLinkUp account before submitting

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
