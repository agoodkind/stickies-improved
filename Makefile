-include Config/local.xcconfig

TUIST := $(shell command -v tuist 2>/dev/null || printf '%s' "mise x tuist@4.111.1 -- tuist")
SWIFTFORMAT := $(shell command -v swiftformat 2>/dev/null || printf '%s' "mise x swiftformat@0.58.5 -- swiftformat")

CONFIGURATION ?= Release
BUILD_DIR ?= build
PRODUCTS_DIR ?= Products
APP_NAME = StickiesImproved
DMG_STAGING_DIR = $(BUILD_DIR)/dmg
DMG_VOLUME_NAME = $(APP_NAME)
DMG_NAME = $(APP_NAME)-$(CONFIGURATION).dmg
DMG_PATH = $(PRODUCTS_DIR)/$(DMG_NAME)
APP_PATH = $(PRODUCTS_DIR)/$(APP_NAME).app
XCODE_PRODUCTS_DIR = $(BUILD_DIR)/Build/Products/$(CONFIGURATION)
BUILT_APP_PATH = $(XCODE_PRODUCTS_DIR)/$(APP_NAME).app
RELEASE_TAG ?= $(CURRENT_PROJECT_VERSION)-$(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
RELEASE_DMG_NAME = $(APP_NAME)-$(CURRENT_PROJECT_VERSION).dmg
RELEASE_DMG_PATH = $(PRODUCTS_DIR)/$(RELEASE_DMG_NAME)
SPARKLE_UPDATES_DIR = $(BUILD_DIR)/sparkle-updates
GITHUB_RELEASE_BASE_URL ?= https://github.com/agoodkind/stickies-improved/releases/download/$(RELEASE_TAG)/

.PHONY: generate-project open-project build test app dmg release-assets prepare-sparkle-updates run clean format

generate-project:
	$(TUIST) generate --no-open

open-project: generate-project
	open StickiesImproved.xcworkspace

build: generate-project
	$(TUIST) xcodebuild build \
		-scheme StickiesImproved \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(BUILD_DIR) \
		MARKETING_VERSION="$(MARKETING_VERSION)" \
		CURRENT_PROJECT_VERSION="$(CURRENT_PROJECT_VERSION)"

test: generate-project
	$(TUIST) xcodebuild test \
		-scheme StickiesImproved \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR)

app: build
	@mkdir -p "$(PRODUCTS_DIR)"
	@rm -rf "$(APP_PATH)"
	@cp -R "$(BUILT_APP_PATH)" "$(APP_PATH)"

dmg: app
	@mkdir -p "$(PRODUCTS_DIR)" "$(DMG_STAGING_DIR)"
	@rm -rf "$(DMG_STAGING_DIR)/$(APP_NAME).app" "$(DMG_STAGING_DIR)/Applications" "$(DMG_PATH)"
	@cp -R "$(APP_PATH)" "$(DMG_STAGING_DIR)/"
	@ln -s /Applications "$(DMG_STAGING_DIR)/Applications"
	hdiutil create -volname "$(DMG_VOLUME_NAME)" \
		-srcfolder "$(DMG_STAGING_DIR)" \
		-fs HFS+ \
		-format UDZO \
		-ov "$(DMG_PATH)"
	@if [ -n "$(DMG_SIGN_IDENTITY)" ]; then \
		codesign --force --sign "$(DMG_SIGN_IDENTITY)" "$(DMG_PATH)"; \
	fi

release-assets: dmg
	@cp "$(DMG_PATH)" "$(RELEASE_DMG_PATH)"

prepare-sparkle-updates:
	@test -f "$(RELEASE_DMG_PATH)"
	@rm -rf "$(SPARKLE_UPDATES_DIR)"
	@mkdir -p "$(SPARKLE_UPDATES_DIR)"
	@cp "$(RELEASE_DMG_PATH)" "$(SPARKLE_UPDATES_DIR)/"
	@SPARKLE_APPCAST_TOOL="$$(Scripts/find-sparkle-tool.sh "$(BUILD_DIR)" generate_appcast)"; \
	if [ -n "$${SPARKLE_PRIVATE_KEY_FILE:-}" ]; then \
		"$${SPARKLE_APPCAST_TOOL}" \
			--ed-key-file "$${SPARKLE_PRIVATE_KEY_FILE}" \
			--download-url-prefix "$(GITHUB_RELEASE_BASE_URL)" \
			"$(SPARKLE_UPDATES_DIR)"; \
	else \
		"$${SPARKLE_APPCAST_TOOL}" \
			--download-url-prefix "$(GITHUB_RELEASE_BASE_URL)" \
			"$(SPARKLE_UPDATES_DIR)"; \
	fi

run: app
	open "$(APP_PATH)"

format:
	$(SWIFTFORMAT) .

clean:
	rm -rf "$(BUILD_DIR)" "$(PRODUCTS_DIR)" StickiesImproved.xcworkspace StickiesImproved.xcodeproj
