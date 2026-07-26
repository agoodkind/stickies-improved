#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE_ROOT="${REPOSITORY_ROOT}/Scripts/Tests/Fixtures"
TEMPORARY_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/stickies-appcast-test.XXXXXX")"

cleanup() {
    rm -rf "${TEMPORARY_DIRECTORY}"
}
trap cleanup EXIT

cp "${FIXTURE_ROOT}/appcast.xml" "${TEMPORARY_DIRECTORY}/appcast.xml"
swift "${REPOSITORY_ROOT}/Scripts/RewriteAppcastURLs.swift" \
    --appcast "${TEMPORARY_DIRECTORY}/appcast.xml" \
    --mapping "${FIXTURE_ROOT}/asset-tags.tsv" \
    --repository agoodkind/stickies-improved

stable_url="https://github.com/agoodkind/stickies-improved/releases/download/26.7.26/StickiesImproved-26.7.26.dmg"
legacy_url="https://github.com/agoodkind/stickies-improved/releases/download/202607230033-34-93803d7/StickiesImproved-20260723003352.dmg"
if ! grep -Fq "${stable_url}" "${TEMPORARY_DIRECTORY}/appcast.xml"; then
    printf 'rewrite-appcast-urls: stable URL was not rewritten\n' >&2
    exit 1
fi
if ! grep -Fq "${legacy_url}" "${TEMPORARY_DIRECTORY}/appcast.xml"; then
    printf 'rewrite-appcast-urls: legacy URL was not rewritten\n' >&2
    exit 1
fi
if grep -Fq "__RELEASE_TAG__" "${TEMPORARY_DIRECTORY}/appcast.xml"; then
    printf 'rewrite-appcast-urls: placeholder URL remains\n' >&2
    exit 1
fi

printf 'rewrite-appcast-urls: passed\n'
