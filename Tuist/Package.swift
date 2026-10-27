//
//  Package.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "StickiesImprovedDependencies",
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.3"),
    .package(url: "https://github.com/automerge/automerge-swift", from: "0.7.2"),
  ]
)

// Xcode 27.1 rejects macOS targets below 12.0; automerge-swift declares 10.15.
// Remove this override after automerge-swift declares macOS 12.0 or later.
#if TUIST
  import ProjectDescription

  let minimumDeploymentTarget: SettingsDictionary = ["MACOSX_DEPLOYMENT_TARGET": "12.0"]

  let packageSettings = PackageSettings(
    targetSettings: [
      "Automerge": .settings(base: minimumDeploymentTarget),
      "AutomergeUniffi": .settings(base: minimumDeploymentTarget),
      "AutomergeUtilities": .settings(base: minimumDeploymentTarget),
    ]
  )
#endif
