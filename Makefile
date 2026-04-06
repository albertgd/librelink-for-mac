APP_NAME = LibreLinkForMac
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
APP_BUNDLE = $(RELEASE_DIR)/$(APP_NAME).app
ICNS_FILE = AppIcon.icns

.PHONY: all build run clean bundle dmg zip icon

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
	rm -f $(RELEASE_DIR)/$(APP_NAME).zip

# Generate .icns from icon.png
icon:
	@echo "Generating app icon..."
	@mkdir -p AppIcon.iconset
	@sips -z 16 16     icon.png --out AppIcon.iconset/icon_16x16.png    > /dev/null
	@sips -z 32 32     icon.png --out AppIcon.iconset/icon_16x16@2x.png > /dev/null
	@sips -z 32 32     icon.png --out AppIcon.iconset/icon_32x32.png    > /dev/null
	@sips -z 64 64     icon.png --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
	@sips -z 128 128   icon.png --out AppIcon.iconset/icon_128x128.png  > /dev/null
	@sips -z 256 256   icon.png --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
	@sips -z 256 256   icon.png --out AppIcon.iconset/icon_256x256.png  > /dev/null
	@sips -z 512 512   icon.png --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
	@sips -z 512 512   icon.png --out AppIcon.iconset/icon_512x512.png  > /dev/null
	@sips -z 1024 1024 icon.png --out AppIcon.iconset/icon_512x512@2x.png > /dev/null
	@iconutil -c icns AppIcon.iconset --output $(ICNS_FILE)
	@rm -rf AppIcon.iconset
	@echo "✅ Icon generated at $(ICNS_FILE)"

# Create .app bundle from the built binary
bundle: icon build
	@echo "Creating app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BUILD_DIR)/release/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp Sources/$(APP_NAME)/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@cp "$(ICNS_FILE)" "$(APP_BUNDLE)/Contents/Resources/$(ICNS_FILE)"
	@printf 'APPL????' > "$(APP_BUNDLE)/Contents/PkgInfo"
	@echo "✅ App bundle created at $(APP_BUNDLE)"

# Create a ZIP of the .app bundle
zip: bundle
	@echo "Creating ZIP..."
	@cd "$(RELEASE_DIR)" && zip -r "$(APP_NAME).zip" "$(APP_NAME).app"
	@echo "✅ ZIP created at $(RELEASE_DIR)/$(APP_NAME).zip"

# Create a DMG (requires hdiutil, macOS only)
dmg: bundle
	@echo "Creating DMG..."
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(APP_BUNDLE)" \
		-ov -format UDZO \
		"$(RELEASE_DIR)/$(APP_NAME).dmg"
	@echo "✅ DMG created at $(RELEASE_DIR)/$(APP_NAME).dmg"
