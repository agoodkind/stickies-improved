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
    private var stateObservers: [NSKeyValueObservation] = []

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

    var isConfigured: Bool {
        guard controller != nil else { return false }
        let publicKey =
            Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        let feedURL =
            Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        return !publicKey.isEmpty && !feedURL.isEmpty
    }

    var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }

    var automaticallyChecksForUpdates: Bool {
        controller?.updater.automaticallyChecksForUpdates ?? false
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        controller?.updater.automaticallyChecksForUpdates = enabled
    }

    func observeStateChanges(_ onChange: @escaping @MainActor () -> Void) {
        for observer in stateObservers {
            observer.invalidate()
        }
        stateObservers = []
        guard let updater = controller?.updater else { return }
        // Sparkle posts these KVO changes on the main thread, so it is safe to hop onto
        // the main actor to forward them to the observing model.
        let forward: (SPUUpdater, NSKeyValueObservedChange<Bool>) -> Void = { _, _ in
            MainActor.assumeIsolated { onChange() }
        }
        stateObservers = [
            updater.observe(\.canCheckForUpdates, options: [.new], changeHandler: forward),
            updater.observe(
                \.automaticallyChecksForUpdates, options: [.new], changeHandler: forward
            ),
        ]
    }
}
