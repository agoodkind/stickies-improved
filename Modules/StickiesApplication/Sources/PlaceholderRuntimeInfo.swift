//
//  PlaceholderRuntimeInfo.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesDomain

/// A safe default so the `runtimeInfo` environment value is non-optional in
/// views. The App replaces it with a `Bundle.main`-backed value at launch.
public struct PlaceholderRuntimeInfo: RuntimeInfoProviding {
    public let bundleIdentifier = "io.goodkind.stickies-improved"
    public let iCloudContainerIdentifier = ""
    public let sparkleFeedURL = ""
    public let marketingVersion = "0.0.0"
    public let buildVersion = "0"

    public init() {
        // Stored constants only; no setup needed.
    }
}
