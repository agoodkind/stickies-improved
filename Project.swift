//
//  Project.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import ProjectDescription

let appName = "StickiesImproved"
// User-facing name; differs from appName (the Xcode target/scheme identifier) so
// the build identity stays space-free while Finder, the menu bar, and the .app
// bundle show the spaced name.
let displayName = "Stickies Improved"
let organizationName = "goodkind.io"
let bundleId = "io.goodkind.stickies-improved"
let deploymentTargets: DeploymentTargets = .macOS("26.0")

let debug = Configuration.debug(
  name: "Debug",
  xcconfig: "Config/debug.xcconfig"
)

let release = Configuration.release(
  name: "Release",
  xcconfig: "Config/release.xcconfig"
)

// Signing identity, team, and style are owned by swift-mk's XCODE_XCCONFIG_FILE
// override, which wins over these target settings, so they are not set here.
let settings = Settings.settings(
  base: [
    "SWIFT_VERSION": "6.0",
    "MARKETING_VERSION": "$(MARKETING_VERSION)",
    "CURRENT_PROJECT_VERSION": "$(CURRENT_PROJECT_VERSION)",
    "ENABLE_HARDENED_RUNTIME": "YES",
    "OTHER_CODE_SIGN_FLAGS": "--timestamp",
  ],
  configurations: [debug, release],
  defaultSettings: .recommended
)

let targetSigningSettings: SettingsDictionary = [
  "CODE_SIGN_INJECT_BASE_ENTITLEMENTS": "NO",
  "ENABLE_HARDENED_RUNTIME": "YES",
  "OTHER_CODE_SIGN_FLAGS": "--timestamp",
  "PROVISIONING_PROFILE_SPECIFIER": "",
]

// swift-mk's XCODE_XCCONFIG_FILE override supplies the identity, team, and style
// (the same method macos-fan-curve uses). Unlike macos-fan-curve, the app declares
// an iCloud capability, which Developer ID distribution requires a provisioning
// profile to authorize, so the app target keeps the profile specifier.
let appSigningSettings = targetSigningSettings.merging([
  "PROVISIONING_PROFILE_SPECIFIER": "$(PROVISIONING_PROFILE_SPECIFIER)"
]) { _, new in new }

let infoPlist: [String: Plist.Value] = [
  "CFBundleDisplayName": .string(displayName),
  "CFBundleName": .string(displayName),
  "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
  "CFBundleVersion": .string("$(CURRENT_PROJECT_VERSION)"),
  "LSApplicationCategoryType": .string("public.app-category.productivity"),
  "NSUbiquitousContainers": .dictionary([
    "$(ICLOUD_CONTAINER_IDENTIFIER)": .dictionary([
      "NSUbiquitousContainerName": .string(displayName),
      "NSUbiquitousContainerSupportedFolderLevels": .string("Any"),
    ])
  ]),
  "SUEnableAutomaticChecks": .boolean(true),
  "SUAllowsAutomaticUpdates": .boolean(true),
  // Hardcoded rather than `$(SPARKLE_FEED_URL)`: an xcconfig value treats `//` as a
  // comment, which truncates the URL to `https:` in the built Info.plist.
  "SUFeedURL": .string("https://goodkind.io/stickies-improved/appcast.xml"),
  "SUPublicEDKey": .string("$(SPARKLE_PUBLIC_ED_KEY)"),
  "GitBranch": .string("$(GIT_BRANCH)"),
  "BuildDate": .string("$(BUILD_DATE)"),
]

let sparkleCurrentPath =
  "$(BUILT_PRODUCTS_DIR)/$(PRODUCT_NAME).app/Contents/Frameworks/Sparkle.framework/Versions/Current"
let sparkleXPCPath = "\(sparkleCurrentPath)/XPCServices"

// Reserve scripting for Sparkle's documented inside-out signing requirement: the
// nested helpers must be signed before the outer app. swift-mk owns the signing
// flags; this phase only names the paths, so nothing here prescribes how to sign.
let signSparkleScript = TargetScript.post(
  path: "Scripts/SignSparkle.swift",
  name: "Sign Sparkle nested code",
  inputPaths: [
    "\(sparkleCurrentPath)/Updater.app",
    "\(sparkleXPCPath)/Downloader.xpc",
    "\(sparkleXPCPath)/Installer.xpc",
    "\(sparkleCurrentPath)/Autoupdate",
    "$(BUILT_PRODUCTS_DIR)/$(PRODUCT_NAME).app/Contents/Frameworks/Sparkle.framework",
  ]
)

// MARK: - Module helpers

func frameworkTarget(
  _ name: String,
  dependencies: [TargetDependency]
) -> Target {
  .target(
    name: name,
    destinations: [.mac],
    product: .framework,
    bundleId: "\(bundleId).\(name.lowercased())",
    deploymentTargets: deploymentTargets,
    infoPlist: .default,
    sources: ["Modules/\(name)/Sources/**"],
    dependencies: dependencies,
    settings: .settings(base: targetSigningSettings)
  )
}

func unitTestTarget(
  _ name: String,
  dependencies: [TargetDependency]
) -> Target {
  .target(
    name: name,
    destinations: [.mac],
    product: .unitTests,
    bundleId: "\(bundleId).\(name.lowercased())",
    deploymentTargets: deploymentTargets,
    infoPlist: .default,
    sources: ["Modules/\(moduleName(forTests: name))/Tests/**"],
    dependencies: dependencies
  )
}

func moduleName(forTests target: String) -> String {
  if target.hasSuffix("Tests") {
    return String(target.dropLast("Tests".count))
  }
  return target
}

// MARK: - Targets

let domain = frameworkTarget("StickiesDomain", dependencies: [])
let persistence = frameworkTarget(
  "StickiesPersistence",
  dependencies: [.target(name: "StickiesDomain")]
)
let designSystem = frameworkTarget(
  "StickiesDesignSystem",
  dependencies: [.target(name: "StickiesDomain")]
)
let crdt = frameworkTarget(
  "StickiesCRDT",
  dependencies: [
    .target(name: "StickiesDomain"),
    .external(name: "Automerge"),
  ]
)
let application = frameworkTarget(
  "StickiesApplication",
  dependencies: [
    .target(name: "StickiesDomain"),
    .target(name: "StickiesCRDT"),
  ]
)
let features = frameworkTarget(
  "StickiesFeatures",
  dependencies: [
    .target(name: "StickiesApplication"),
    .target(name: "StickiesDesignSystem"),
    .target(name: "StickiesDomain"),
  ]
)
let testSupport = frameworkTarget(
  "StickiesTestSupport",
  dependencies: [.target(name: "StickiesDomain")]
)

let app: Target = .target(
  name: appName,
  destinations: [.mac],
  product: .app,
  bundleId: bundleId,
  deploymentTargets: deploymentTargets,
  infoPlist: .extendingDefault(with: infoPlist),
  sources: ["App/**"],
  resources: [],
  entitlements: "Config/StickiesImproved.entitlements",
  scripts: [signSparkleScript],
  dependencies: [
    .target(name: "StickiesFeatures"),
    .target(name: "StickiesApplication"),
    .target(name: "StickiesDesignSystem"),
    .target(name: "StickiesPersistence"),
    .target(name: "StickiesCRDT"),
    .target(name: "StickiesDomain"),
    .external(name: "Sparkle"),
  ],
  settings: .settings(
    base: appSigningSettings.merging([
      "PRODUCT_NAME": .string(displayName),
      // The .app bundle is "Stickies Improved.app" (PRODUCT_NAME), but the Mach-O
      // binary stays space-free so tooling that touches the executable path is safe.
      "EXECUTABLE_NAME": .string(appName),
      "PRODUCT_BUNDLE_IDENTIFIER": .string("$(APP_BUNDLE_ID)"),
    ]) { _, new in new }
  )
)

let domainTests = unitTestTarget(
  "StickiesDomainTests",
  dependencies: [.target(name: "StickiesDomain")]
)
let designSystemTests = unitTestTarget(
  "StickiesDesignSystemTests",
  dependencies: [.target(name: "StickiesDesignSystem")]
)
let persistenceTests = unitTestTarget(
  "StickiesPersistenceTests",
  dependencies: [
    .target(name: "StickiesPersistence"),
    .target(name: "StickiesTestSupport"),
  ]
)
let crdtTests = unitTestTarget(
  "StickiesCRDTTests",
  dependencies: [
    .target(name: "StickiesCRDT"),
    .target(name: "StickiesDomain"),
  ]
)
let applicationTests = unitTestTarget(
  "StickiesApplicationTests",
  dependencies: [
    .target(name: "StickiesApplication"),
    .target(name: "StickiesCRDT"),
    .target(name: "StickiesTestSupport"),
  ]
)
let featuresTests = unitTestTarget(
  "StickiesFeaturesTests",
  dependencies: [
    .target(name: "StickiesFeatures"),
    .target(name: "StickiesDomain"),
  ]
)

let project = Project(
  name: appName,
  organizationName: organizationName,
  settings: settings,
  targets: [
    domain,
    persistence,
    designSystem,
    crdt,
    application,
    features,
    testSupport,
    app,
    domainTests,
    designSystemTests,
    persistenceTests,
    crdtTests,
    applicationTests,
    featuresTests,
  ],
  schemes: [
    .scheme(
      name: appName,
      shared: true,
      buildAction: .buildAction(targets: ["\(appName)"]),
      testAction: .targets(
        [
          "StickiesDomainTests",
          "StickiesDesignSystemTests",
          "StickiesPersistenceTests",
          "StickiesCRDTTests",
          "StickiesApplicationTests",
          "StickiesFeaturesTests",
        ],
        configuration: "Debug"
      ),
      runAction: .runAction(configuration: "Debug"),
      archiveAction: .archiveAction(configuration: "Release"),
      profileAction: .profileAction(configuration: "Release"),
      analyzeAction: .analyzeAction(configuration: "Debug")
    )
  ]
)
