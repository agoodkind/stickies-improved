#!/bin/bash
set -euo pipefail

GENERATED_DIR="${DERIVED_FILE_DIR}/Generated"
TEMPLATES_DIR="${SRCROOT}/Templates"

mkdir -p "${GENERATED_DIR}"

APP_BUNDLE_ID="${APP_BUNDLE_ID:-io.goodkind.stickies-improved}"
ICLOUD_CONTAINER_IDENTIFIER="${ICLOUD_CONTAINER_IDENTIFIER:-H3BMXM4W7H.io.goodkind.stickies-improved}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://goodkind.io/stickies-improved/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"

# Git branch and build timestamp for the About build details. Fall back gracefully
# outside a git checkout so the generated file always compiles.
GIT_BRANCH="$(git -C "${SRCROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
BUILD_DATE="$(date -u '+%Y-%m-%d %H:%M UTC')"

sed \
  -e "s|@@APP_BUNDLE_ID@@|${APP_BUNDLE_ID}|g" \
  -e "s|@@ICLOUD_CONTAINER_IDENTIFIER@@|${ICLOUD_CONTAINER_IDENTIFIER}|g" \
  -e "s|@@SPARKLE_FEED_URL@@|${SPARKLE_FEED_URL}|g" \
  -e "s|@@SPARKLE_PUBLIC_ED_KEY@@|${SPARKLE_PUBLIC_ED_KEY}|g" \
  -e "s|@@CURRENT_PROJECT_VERSION@@|${CURRENT_PROJECT_VERSION}|g" \
  -e "s|@@MARKETING_VERSION@@|${MARKETING_VERSION}|g" \
  -e "s|@@GIT_BRANCH@@|${GIT_BRANCH}|g" \
  -e "s|@@BUILD_DATE@@|${BUILD_DATE}|g" \
  "${TEMPLATES_DIR}/Config.generated.swift.template" \
  > "${GENERATED_DIR}/Config.generated.swift"
