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
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1"),
        .package(url: "https://github.com/automerge/automerge-swift", from: "0.7.2"),
    ]
)
