//
//  RuntimeInfoProviding.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

/// Surfaces the bundle and version facts that views display, so the concrete
/// `Bundle.main` reads stay in the App composition root rather than coupling
/// the feature layer to a static configuration enum.
public protocol RuntimeInfoProviding: Sendable {
    var bundleIdentifier: String { get }
    var iCloudContainerIdentifier: String { get }
    var sparkleFeedURL: String { get }
    var marketingVersion: String { get }
    var buildVersion: String { get }
    /// The git branch the binary was built from, for the About build details.
    var gitBranch: String { get }
    /// The build timestamp, for the About build details.
    var buildDate: String { get }
}
