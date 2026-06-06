//
//  UpdaterModelTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesDomain
import Testing

@testable import StickiesApplication

/// A deterministic `UpdaterControlling` for tests: it records calls and lets a test push
/// state changes so the observing model can be verified without Sparkle.
@MainActor
private final class FakeUpdaterController: UpdaterControlling {
    var isConfigured: Bool
    var canCheckForUpdates: Bool
    var automaticallyChecksForUpdates: Bool
    private(set) var checkForUpdatesCallCount = 0

    private var onChange: (@MainActor () -> Void)?

    init(
        isConfigured: Bool = true,
        canCheckForUpdates: Bool = true,
        automaticallyChecksForUpdates: Bool = true
    ) {
        self.isConfigured = isConfigured
        self.canCheckForUpdates = canCheckForUpdates
        self.automaticallyChecksForUpdates = automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        checkForUpdatesCallCount += 1
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        automaticallyChecksForUpdates = enabled
        onChange?()
    }

    func observeStateChanges(_ onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    func setCanCheckForUpdates(_ value: Bool) {
        canCheckForUpdates = value
        onChange?()
    }
}

// MARK: - UpdaterModelTests

@MainActor
struct UpdaterModelTests {
    @Test func mirrorsControllerInitialState() {
        let controller = FakeUpdaterController(
            isConfigured: true,
            canCheckForUpdates: false,
            automaticallyChecksForUpdates: true
        )

        let model = UpdaterModel(controller: controller)

        #expect(model.isConfigured)
        #expect(!model.canCheckForUpdates)
        #expect(model.automaticallyChecksForUpdates)
    }

    @Test func refreshesWhenControllerBecomesReady() {
        let controller = FakeUpdaterController(canCheckForUpdates: false)
        let model = UpdaterModel(controller: controller)

        controller.setCanCheckForUpdates(true)

        #expect(model.canCheckForUpdates)
    }

    @Test func togglingAutomaticChecksUpdatesControllerAndModel() {
        let controller = FakeUpdaterController(automaticallyChecksForUpdates: false)
        let model = UpdaterModel(controller: controller)

        model.setAutomaticallyChecksForUpdates(true)

        #expect(controller.automaticallyChecksForUpdates)
        #expect(model.automaticallyChecksForUpdates)
    }

    @Test func checkForUpdatesForwardsToController() {
        let controller = FakeUpdaterController()
        let model = UpdaterModel(controller: controller)

        model.checkForUpdates()

        #expect(controller.checkForUpdatesCallCount == 1)
    }
}
