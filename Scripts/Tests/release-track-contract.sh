#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail() {
    printf 'release-track-contract: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    local file_path
    local expected_text

    file_path=$1
    expected_text=$2
    if ! grep -Fq -- "${expected_text}" "${REPOSITORY_ROOT}/${file_path}"; then
        fail "${file_path} does not contain: ${expected_text}"
    fi
}

assert_not_contains() {
    local file_path
    local unexpected_text

    file_path=$1
    unexpected_text=$2
    if grep -Fq -- "${unexpected_text}" "${REPOSITORY_ROOT}/${file_path}"; then
        fail "${file_path} still contains: ${unexpected_text}"
    fi
}

assert_contains ".github/workflows/release.yml" "release-track:"
assert_contains ".github/workflows/release.yml" "candidate-tag:"
assert_contains ".github/workflows/release.yml" "source-sha:"
assert_contains ".github/workflows/release.yml" "allow-source-sha:"
assert_contains ".github/workflows/release.yml" "uses: ./.github/workflows/appcast.yml"
assert_contains ".github/workflows/release.yml" "needs.release.outputs['release-tag']"
assert_contains ".github/workflows/release.yml" "needs.release.outputs['release-track']"

assert_contains ".github/workflows/appcast.yml" "workflow_call:"
assert_contains ".github/workflows/appcast.yml" "release_tag:"
assert_contains ".github/workflows/appcast.yml" "release_track:"
assert_contains ".github/workflows/appcast.yml" "Scripts/prepare-appcast-history.sh"
assert_contains ".github/workflows/appcast.yml" \
    "uses: agoodkind/swift-makefile/.github/actions/stage-appcast-assets@main"
# shellcheck disable=SC2016 # The assertion matches literal GitHub Actions syntax.
assert_contains ".github/workflows/appcast.yml" 'release-track: ${{ inputs.release_track }}'
assert_contains ".github/workflows/appcast.yml" \
    "appcast-source: build/sparkle-updates/appcast.xml"
assert_contains ".github/workflows/appcast.yml" \
    "public-directory: deploy/appcast-worker/public"
assert_contains ".github/workflows/appcast.yml" \
    "stable-feed-url: https://goodkind.io/stickies-improved/appcast.xml"
assert_contains ".github/workflows/appcast.yml" \
    "prerelease-feed-url: https://goodkind.io/stickies-improved/prerelease/appcast.xml"
assert_not_contains ".github/workflows/appcast.yml" "git tag --points-at"
assert_not_contains ".github/workflows/appcast.yml" "build_version=\"\${dmg_name"
assert_not_contains ".github/workflows/appcast.yml" "public_path="

assert_contains "Makefile" "ARTIFACT_VERSION ?= Release"
assert_contains "Makefile" "SWIFT_APP_RELEASE_DMG_NAME :="
assert_contains "Makefile" "SPARKLE_APPCAST_PATH :="
assert_contains "Project.swift" "stickies-improved/\$(SPARKLE_APPCAST_PATH)"

assert_contains "App/StickiesImprovedApp.swift" "enabled: Self.sparkleUpdatesEnabled"
assert_contains "App/StickiesImprovedApp.swift" "#if DEBUG"
assert_contains "Modules/StickiesFeatures/Sources/AboutView.swift" "if isUpdaterConfigured"
assert_contains "Modules/StickiesFeatures/Sources/SettingsView.swift" "if isUpdaterConfigured"
assert_contains "Modules/StickiesFeatures/Sources/NoteCommands.swift" "if updaterModel.isConfigured"

printf 'release-track-contract: passed\n'
