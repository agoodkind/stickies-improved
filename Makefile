-include Config/local.xcconfig

# Expose the signing identity under the name swift-mk reads, so swift-mk owns
# build-time signing through its XCODE_XCCONFIG_FILE override. Locally the value
# comes from SIGNING_CERTIFICATE in local.xcconfig; CI sets CODE_SIGN_IDENTITY.
CODE_SIGN_IDENTITY ?= $(SIGNING_CERTIFICATE)

CONFIGURATION ?= Release
BUILD_DIR ?= build
RELEASE_TAG ?= $(CURRENT_PROJECT_VERSION)-$(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
BUILD_DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
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

# Canonical Xcode-app build path: declare the generator, workspace, scheme, and
# configuration, and swift-mk derives build/test/generate/coverage through the
# `swift-mk toolchain` chokepoint. This Makefile names no tuist/xcodegen/xcodebuild.
SWIFT_XCODE_GENERATOR := tuist
SWIFT_XCODE_WORKSPACE := $(SWIFT_APP_NAME).xcworkspace
SWIFT_XCODE_SCHEME := $(SWIFT_APP_NAME)
SWIFT_XCODE_CONFIGURATION := $(CONFIGURATION)
SWIFT_XCODE_BUILD_SETTINGS := MARKETING_VERSION="$(MARKETING_VERSION)" CURRENT_PROJECT_VERSION="$(CURRENT_PROJECT_VERSION)" GIT_BRANCH="$(GIT_BRANCH)" BUILD_DATE="$(BUILD_DATE)"
SWIFT_CLEAN_CMD := rm -rf $(BUILD_DIR) Products StickiesImproved.xcworkspace StickiesImproved.xcodeproj
SWIFTLINT_TARGETS := $(SWIFT_SOURCE_TARGETS)
SWIFT_FORMAT_TARGETS := $(SWIFT_SOURCE_TARGETS)
SWIFTCHECK_EXTRA_TARGETS := $(SWIFT_SOURCE_TARGETS)

include bootstrap.mk
.DEFAULT_GOAL := check

.PHONY: run
run: app
	open "$(SWIFT_APP_DEST)"
