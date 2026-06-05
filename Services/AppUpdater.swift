//
//  AppUpdater.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Observation
import Sparkle

@preconcurrency
@Observable
@MainActor
public final class AppUpdater {
    private let controller: SPUStandardUpdaterController?

    public init(enabled: Bool = true) {
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

    public func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
