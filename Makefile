APP_NAME = LibreLinkForMac
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
APP_BUNDLE = $(RELEASE_DIR)/$(APP_NAME).app

.PHONY: all build run clean bundle dmg

all: bundle

# Build the Swift package in release mode
build:
	swift build -c release

# Run in debug mode
run:
	swift run

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(RELEASE_DIR)/$(APP_NAME).app
	rm -f $(RELEASE_DIR)/$(APP_NAME).dmg

# Create .app bundle from the built binary
bundle: build
	@echo "Creating app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BUILD_DIR)/release/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp Sources/$(APP_NAME)/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@echo "APPL????" > "$(APP_BUNDLE)/Contents/PkgInfo"
	@echo "✅ App bundle created at $(APP_BUNDLE)"

# Create a DMG (requires hdiutil, macOS only)
dmg: bundle
	@echo "Creating DMG..."
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(APP_BUNDLE)" \
		-ov -format UDZO \
		"$(RELEASE_DIR)/$(APP_NAME).dmg"
	@echo "✅ DMG created at $(RELEASE_DIR)/$(APP_NAME).dmg"
