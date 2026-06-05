//
//  SparkleUpdaterController.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Sparkle
import StickiesDomain

/// The only file that imports Sparkle. It wraps `SPUStandardUpdaterController`
/// behind the `UpdaterControlling` seam so the rest of the app never names the
/// concrete updater type.
@MainActor
final class SparkleUpdaterController: UpdaterControlling {
    private let controller: SPUStandardUpdaterController?

    init(enabled: Bool) {
        if enabled {
            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            controller = nil
        }
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
