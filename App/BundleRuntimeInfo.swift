//
//  BundleRuntimeInfo.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain

/// Reads the bundle and version facts from `Bundle.main`, keeping every concrete
/// Bundle lookup in the composition root rather than the feature layer.
struct BundleRuntimeInfo: RuntimeInfoProviding {
    static let realiCloudContainerIdentifier = "H3BMXM4W7H.io.goodkind.stickies-improved"

    let bundleIdentifier =
        Bundle.main.bundleIdentifier ?? "io.goodkind.stickies-improved"
    let iCloudContainerIdentifier = realiCloudContainerIdentifier
    let sparkleFeedURL =
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
    let marketingVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        ?? "0.1.0"
    let buildVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    // Git branch and build timestamp are baked into custom Info.plist keys by the build
    // (`$(GIT_BRANCH)` / `$(BUILD_DATE)`), so reads stay in the composition root.
    let gitBranch = Self.infoString("GitBranch")
    let buildDate = Self.infoString("BuildDate")

    private static func infoString(_ key: String) -> String {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
        return value.isEmpty ? "unknown" : value
    }
}
