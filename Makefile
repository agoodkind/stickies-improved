-include Config/local.xcconfig

# Expose the signing identity under the name swift-mk reads, so swift-mk owns
# build-time signing through its XCODE_XCCONFIG_FILE override. Locally the value
# comes from SIGNING_CERTIFICATE in local.xcconfig; CI sets CODE_SIGN_IDENTITY.
CODE_SIGN_IDENTITY ?= $(SIGNING_CERTIFICATE)

CONFIGURATION ?= Release
BUILD_DIR ?= build
# Local-dev defaults; the release workflow's release-meta overrides both via the
# environment. They are not pinned in local.xcconfig, so the env value wins (a
# makefile assignment from `-include` would otherwise shadow it).
MARKETING_VERSION ?= 0.1.0
CURRENT_PROJECT_VERSION ?= 1
RELEASE_TAG ?= $(CURRENT_PROJECT_VERSION)-$(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
GIT_BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
BUILD_DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
SWIFT_SOURCE_TARGETS := Modules App Project.swift Tuist.swift Tuist/Package.swift

SWIFT_MK_MODULES := swift-build.mk swift-app.mk swift-release.mk
SWIFT_MK_DERIVED_DATA := $(BUILD_DIR)
SWIFT_MK_OWN_RUN := 1

SWIFT_APP_NAME := StickiesImproved
# The .app basename and mounted dmg volume title carry the spaced display name; the
# dmg filename keeps SWIFT_APP_NAME (space-free) because the shared _release.yml
# notarize step word-splits the artifact path. This mirrors macos-fan-curve.
SWIFT_APP_BUNDLE_NAME := Stickies Improved
SWIFT_APP_DMG_VOLUME_NAME := $(SWIFT_APP_BUNDLE_NAME)
SWIFT_APP_CONFIGURATION := $(CONFIGURATION)
SWIFT_APP_BUILD_DIR := $(BUILD_DIR)
SWIFT_APP_SIGN_IDENTITY := $(DMG_SIGN_IDENTITY)
SWIFT_APP_GITHUB_RELEASE_BASE_URL := https://github.com/agoodkind/stickies-improved/releases/download/$(RELEASE_TAG)/
SWIFT_APP_SPARKLE_APPCAST_TOOL_CMD := Scripts/find-sparkle-tool.sh "$(BUILD_DIR)" generate_appcast

# The Sparkle public key is the one release value not already constant in the
# committed Config/local.xcconfig, so pass it as a top-precedence build setting
# (below) to embed SUPublicEDKey. `:=` not `?=`: local.xcconfig is `-include`d
# above with an empty value that would otherwise shadow the file read.
SPARKLE_PUBLIC_ED_KEY := $(shell cat Config/sparkle.pub 2>/dev/null)
XCODE_PROVISIONING_PROFILE_SPECIFIER ?= $(PROVISIONING_PROFILE_SPECIFIER)
XCODE_CODE_SIGNING_ALLOWED ?= YES
XCODE_CODE_SIGNING_REQUIRED ?= YES

# release-build (canonical `_release.yml`): build and sign the app and dmg through
# swift-app.mk's release-assets, then place the versioned dmg in dist/ for the
# notarize job. The bundle id, iCloud container, and profile specifier are
# constants in local.xcconfig; signing comes from swift-mk's override.
# swift-release.mk runs this through `eval "$(SWIFT_MK_RELEASE_BUILD_CMD)"`, whose
# outer double quotes would cancel inner double quotes around the path; single-quote
# the path so it survives the eval regardless of spaces.
SWIFT_MK_RELEASE_BUILD_CMD = $(MAKE) SWIFT_MK_SKIP_FETCH=1 release-assets && mkdir -p dist && cp '$(SWIFT_APP_RELEASE_DMG_PATH)' dist/

# Canonical Xcode-app build path: declare the generator, workspace, scheme, and
# configuration, and swift-mk derives build/test/generate/coverage through the
# `swift-mk toolchain` chokepoint. This Makefile names no tuist/xcodegen/xcodebuild.
SWIFT_XCODE_GENERATOR := tuist
SWIFT_XCODE_WORKSPACE := $(SWIFT_APP_NAME).xcworkspace
SWIFT_XCODE_SCHEME := $(SWIFT_APP_NAME)
SWIFT_XCODE_CONFIGURATION := $(CONFIGURATION)
SWIFT_XCODE_BUILD_SETTINGS := MARKETING_VERSION="$(MARKETING_VERSION)" CURRENT_PROJECT_VERSION="$(CURRENT_PROJECT_VERSION)" GIT_BRANCH="$(GIT_BRANCH)" BUILD_DATE="$(BUILD_DATE)" SPARKLE_PUBLIC_ED_KEY="$(SPARKLE_PUBLIC_ED_KEY)" PROVISIONING_PROFILE_SPECIFIER="$(XCODE_PROVISIONING_PROFILE_SPECIFIER)" CODE_SIGNING_ALLOWED="$(XCODE_CODE_SIGNING_ALLOWED)" CODE_SIGNING_REQUIRED="$(XCODE_CODE_SIGNING_REQUIRED)"
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
