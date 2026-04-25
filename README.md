# PlainStickies

PlainStickies is a native macOS sticky-notes app built with SwiftUI and Tuist.
It ships plain-text notes in v1, uses an app-managed iCloud document library,
and is structured so a Markdown editor can be added later without reworking the
note model or release pipeline.

## Tooling

- `mise install`
- `mise x tuist@4.111.1 -- tuist generate --no-open`
- `make build`
- `make test`

## Release Secrets

GitHub Actions expects these repository secrets:

- `APPLE_DEVELOPER_ID_P12_BASE64`
- or `APPLE_DEVELOPER_ID_P12_BASE64_PART1` and `APPLE_DEVELOPER_ID_P12_BASE64_PART2`
- `APPLE_DEVELOPER_ID_P12_PASSWORD`
- `APPLE_NOTARY_KEY_BASE64`
- `APPLE_NOTARY_ISSUER_ID`
- `SPARKLE_PUBLIC_ED_KEY`
- `SPARKLE_PRIVATE_ED_KEY`
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

Sparkle appcast signing is part of the default release path. The workflow writes
`SPARKLE_PUBLIC_ED_KEY` into `Config/local.xcconfig` for release builds and uses
`SPARKLE_PRIVATE_ED_KEY` to sign appcast assets.

## Update Feed Hosting

Sparkle updates are published at
`https://goodkind.io/plainstickies/appcast.xml`.
The Cloudflare Worker for that route lives under
`deploy/appcast-worker/`, and the release workflow copies the generated
`build/sparkle-updates/appcast.xml` into the worker's `public/` assets
before deploying with Wrangler.
