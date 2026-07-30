#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DRY_RUN_OUTPUT="$(mktemp)"

cleanup() {
    rm -f "${DRY_RUN_OUTPUT}"
}
trap cleanup EXIT INT TERM

cd "${REPOSITORY_ROOT}"
make --no-print-directory --dry-run run >"${DRY_RUN_OUTPUT}"

if ! grep -Fq "env -u SWIFT_BUILD_CMD -u SWIFT_MK_FRESH_CONFIG_KEY" "${DRY_RUN_OUTPUT}"; then
    printf 'make-run-debug: make run did not clear the inherited Release build state\n' >&2
    exit 1
fi

if grep -Eq 'CODE_SIGNING_(ALLOWED|REQUIRED)=' "${DRY_RUN_OUTPUT}"; then
    printf 'make-run-debug: make run bypassed the swift-mk signing source\n' >&2
    exit 1
fi

if ! grep -Fq 'SWIFT_MK_REQUIRE_SIGNING=1' "${DRY_RUN_OUTPUT}"; then
    printf 'make-run-debug: make run did not require the shared signing source\n' >&2
    exit 1
fi

if ! grep -Fq 'XCODE_XCCONFIG_FILE=' "${DRY_RUN_OUTPUT}" ||
    ! grep -Fq '/Config/run.xcconfig' "${DRY_RUN_OUTPUT}"; then
    printf 'make-run-debug: make run did not scope signing to the run build\n' >&2
    exit 1
fi

if ! grep -Fq "build-fresh check --product 'build/Build/Products/Debug/Stickies'" \
    "${DRY_RUN_OUTPUT}"; then
    printf 'make-run-debug: make run did not validate the Debug build product\n' >&2
    exit 1
fi

if ! grep -Fq 'cp -R "build/Build/Products/Debug/Stickies Improved.app"' \
    "${DRY_RUN_OUTPUT}"; then
    printf 'make-run-debug: make run did not stage the Debug build product\n' >&2
    exit 1
fi

if ! grep -Fq 'codesign --verify --deep --strict' "${DRY_RUN_OUTPUT}"; then
    printf 'make-run-debug: make run did not verify the staged Debug bundle\n' >&2
    exit 1
fi

printf 'make-run-debug: passed\n'
