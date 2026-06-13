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

SWIFT_MK_MODULES := swift-build.mk swift-app.mk swift-release.mk
SWIFT_MK_DERIVED_DATA := $(BUILD_DIR)
SWIFT_MK_OWN_RUN := 1

SWIFT_APP_NAME := StickiesImproved
SWIFT_APP_CONFIGURATION := $(CONFIGURATION)
SWIFT_APP_BUILD_DIR := $(BUILD_DIR)
SWIFT_APP_SIGN_IDENTITY := $(DMG_SIGN_IDENTITY)
SWIFT_APP_GITHUB_RELEASE_BASE_URL := https://github.com/agoodkind/stickies-improved/releases/download/$(RELEASE_TAG)/
SWIFT_APP_SPARKLE_APPCAST_TOOL_CMD := Scripts/find-sparkle-tool.sh "$(BUILD_DIR)" generate_appcast

# Release config the canonical `_release.yml` build feeds to write-release-xcconfig.sh.
# The signing identity, profile specifier, team, and versions arrive from the
# workflow; the bundle id, iCloud container, Sparkle feed, and the committed
# public key live here so the make build is self-contained.
APP_BUNDLE_ID := io.goodkind.stickies-improved
ICLOUD_CONTAINER_IDENTIFIER := H3BMXM4W7H.io.goodkind.stickies-improved
SPARKLE_FEED_URL := https://goodkind.io/stickies-improved/appcast.xml
# `:=` not `?=`: the committed local.xcconfig is `-include`d above and defines an
# empty SPARKLE_PUBLIC_ED_KEY, which would otherwise shadow the file read.
SPARKLE_PUBLIC_ED_KEY := $(shell cat Config/sparkle.pub 2>/dev/null)

# release-build (canonical `_release.yml`): write the release xcconfig from the
# workflow + repo values, build and sign the app and dmg through swift-app.mk's
# release-assets, then place the versioned dmg in dist/ for the notarize job.
SWIFT_MK_RELEASE_BUILD_CMD = \
	APP_BUNDLE_ID="$(APP_BUNDLE_ID)" \
	ICLOUD_CONTAINER_IDENTIFIER="$(ICLOUD_CONTAINER_IDENTIFIER)" \
	DEVELOPMENT_TEAM="$(DEVELOPMENT_TEAM)" \
	CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
	PROVISIONING_PROFILE_SPECIFIER="$(PROVISIONING_PROFILE_SPECIFIER)" \
	MARKETING_VERSION="$(MARKETING_VERSION)" \
	CURRENT_PROJECT_VERSION="$(CURRENT_PROJECT_VERSION)" \
	SPARKLE_FEED_URL="$(SPARKLE_FEED_URL)" \
	SPARKLE_PUBLIC_ED_KEY="$(SPARKLE_PUBLIC_ED_KEY)" \
	DMG_SIGN_IDENTITY="$(DMG_SIGN_IDENTITY)" \
	Scripts/write-release-xcconfig.sh \
	&& $(MAKE) SWIFT_MK_SKIP_FETCH=1 release-assets \
	&& mkdir -p dist \
	&& cp "$(SWIFT_APP_RELEASE_DMG_PATH)" dist/

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

.PHONY: install-dependencies
install-dependencies: swift-mk-bin
	"$(SWIFT_MK_BIN)" toolchain install --generator $(SWIFT_XCODE_GENERATOR)

.PHONY: run
run: app
	open "$(SWIFT_APP_DEST)"
