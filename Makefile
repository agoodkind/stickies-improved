-include Config/local.xcconfig

# Expose the signing identity under the name swift-mk reads, so swift-mk owns
# build-time signing through its XCODE_XCCONFIG_FILE override. Locally the value
# comes from SIGNING_CERTIFICATE in local.xcconfig; CI sets CODE_SIGN_IDENTITY.
CODE_SIGN_IDENTITY ?= $(SIGNING_CERTIFICATE)

TUIST := $(shell command -v tuist 2>/dev/null || printf '%s' "mise x tuist@4.111.1 -- tuist")
CONFIGURATION ?= Release
BUILD_DIR ?= build
RELEASE_TAG ?= $(CURRENT_PROJECT_VERSION)-$(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
SWIFT_SOURCE_TARGETS := Modules App Project.swift Tuist.swift Tuist/Package.swift

SWIFT_MK_MODULES := swift-build.mk swift-app.mk
SWIFT_MK_DERIVED_DATA := $(BUILD_DIR)
SWIFT_MK_OWN_RUN := 1

SWIFT_APP_NAME := StickiesImproved
SWIFT_APP_CONFIGURATION := $(CONFIGURATION)
SWIFT_APP_BUILD_DIR := $(BUILD_DIR)
SWIFT_APP_SIGN_IDENTITY := $(DMG_SIGN_IDENTITY)
SWIFT_APP_GITHUB_RELEASE_BASE_URL := https://github.com/agoodkind/stickies-improved/releases/download/$(RELEASE_TAG)/
SWIFT_APP_SPARKLE_APPCAST_TOOL_CMD := Scripts/find-sparkle-tool.sh "$(BUILD_DIR)" generate_appcast

# Recursive (=) so $(SWIFT_MK_XCODEBUILD_ARGS) from swift.mk binds at recipe time.
SWIFT_GENERATE_CMD := $(TUIST) generate --no-open
SWIFT_BUILD_CMD = $(TUIST) xcodebuild build -scheme $(SWIFT_APP_NAME) -configuration $(CONFIGURATION) -derivedDataPath $(BUILD_DIR) $(SWIFT_MK_XCODEBUILD_ARGS) MARKETING_VERSION="$(MARKETING_VERSION)" CURRENT_PROJECT_VERSION="$(CURRENT_PROJECT_VERSION)"
SWIFT_TEST_CMD = $(TUIST) xcodebuild test -scheme $(SWIFT_APP_NAME) -configuration Debug -derivedDataPath $(BUILD_DIR) $(SWIFT_MK_XCODEBUILD_ARGS)
SWIFT_DEADCODE_BUILD_CMD := $(MAKE) app-coverage-build
# Build-for-testing so the test targets and StickiesTestSupport compile too,
# giving the dead-code gate an index unit for every source under Modules/.
SWIFT_APP_COVERAGE_BUILD_CMD = $(TUIST) xcodebuild build-for-testing -scheme $(SWIFT_APP_NAME) -configuration Debug -derivedDataPath $(BUILD_DIR) $(SWIFT_MK_XCODEBUILD_ARGS) COMPILER_INDEX_STORE_ENABLE=YES
SWIFT_CLEAN_CMD := rm -rf $(BUILD_DIR) Products StickiesImproved.xcworkspace StickiesImproved.xcodeproj
SWIFTLINT_TARGETS := $(SWIFT_SOURCE_TARGETS)
SWIFT_FORMAT_TARGETS := $(SWIFT_SOURCE_TARGETS)
SWIFTCHECK_EXTRA_TARGETS := $(SWIFT_SOURCE_TARGETS)

include bootstrap.mk
.DEFAULT_GOAL := check

.PHONY: run
run: app
	open "$(SWIFT_APP_DEST)"
