//
//  PreferencesModelTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain
import Testing

@testable import StickiesApplication

@MainActor
struct PreferencesModelTests {
  private func makeModel() -> (PreferencesModel, UserDefaults) {
    let suiteName = "io.goodkind.stickies-improved.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    return (PreferencesModel(defaults: defaults), defaults)
  }

  @Test func storageModeDefaultsToiCloudAndPersists() {
    let (model, defaults) = makeModel()

    #expect(model.storageMode == .default)

    model.storageMode = .local

    #expect(model.storageMode == .local)
    #expect(defaults.string(forKey: StorageMode.defaultsKey) == StorageMode.local.rawValue)
  }

  @Test func unfocusedTransparencyPersistsToBridgeKey() {
    let (model, defaults) = makeModel()

    model.unfocusedTransparency = 0.7

    #expect(model.unfocusedTransparency == 0.7)
    #expect(defaults.double(forKey: "nonFocusTransparency") == 0.7)
  }

  @Test func unfocusedTransparencyClampsToBounds() {
    let (model, _) = makeModel()

    model.unfocusedTransparency = 0.1
    #expect(model.unfocusedTransparency == PreferencesModel.Bounds.minimumTransparency)

    model.unfocusedTransparency = 5
    #expect(model.unfocusedTransparency == PreferencesModel.Bounds.maximumTransparency)
  }

  @Test func defaultColorPersistsAndReadsBack() {
    let (model, _) = makeModel()

    #expect(model.defaultColor == .default)

    model.defaultColor = .green

    #expect(model.defaultColor == .green)
  }

  @Test func verbosityPersistsAndClamps() {
    let (model, _) = makeModel()

    model.verbosity = 2
    #expect(model.verbosity == 2)

    model.verbosity = 9
    #expect(model.verbosity == PreferencesModel.Bounds.maximumVerbosity)

    model.verbosity = -4
    #expect(model.verbosity == PreferencesModel.Bounds.minimumVerbosity)
  }
}
