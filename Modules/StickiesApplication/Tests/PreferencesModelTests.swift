//
//  PreferencesModelTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain
import StickiesTestSupport
import Testing

@testable import StickiesApplication

@MainActor
struct PreferencesModelTests {
  private func makeModel() throws -> (PreferencesModel, ScratchDefaults) {
    let scratch = try ScratchDefaults(label: "preferences-model-tests")
    return (PreferencesModel(defaults: scratch.defaults), scratch)
  }

  @Test func storageModeDefaultsToiCloudAndPersists() throws {
    let (model, scratch) = try makeModel()

    #expect(model.storageMode == .default)

    model.storageMode = .local

    #expect(model.storageMode == .local)
    #expect(
      scratch.defaults.string(forKey: StorageMode.defaultsKey) == StorageMode.local.rawValue)
  }

  @Test func unfocusedTransparencyPersistsToBridgeKey() throws {
    let (model, scratch) = try makeModel()

    model.unfocusedTransparency = 0.7

    #expect(model.unfocusedTransparency == 0.7)
    #expect(scratch.defaults.double(forKey: "nonFocusTransparency") == 0.7)
  }

  @Test func unfocusedTransparencyClampsToBounds() throws {
    let (model, scratch) = try makeModel()
    withExtendedLifetime(scratch) {
      model.unfocusedTransparency = 0.1
      #expect(model.unfocusedTransparency == PreferencesModel.Bounds.minimumTransparency)

      model.unfocusedTransparency = 5
      #expect(model.unfocusedTransparency == PreferencesModel.Bounds.maximumTransparency)
    }
  }

  @Test func defaultColorPersistsAndReadsBack() throws {
    let (model, scratch) = try makeModel()
    withExtendedLifetime(scratch) {
      #expect(model.defaultColor == .default)

      model.defaultColor = .green

      #expect(model.defaultColor == .green)
    }
  }

  @Test func verbosityPersistsAndClamps() throws {
    let (model, scratch) = try makeModel()
    withExtendedLifetime(scratch) {
      model.verbosity = 2
      #expect(model.verbosity == 2)

      model.verbosity = 9
      #expect(model.verbosity == PreferencesModel.Bounds.maximumVerbosity)

      model.verbosity = -4
      #expect(model.verbosity == PreferencesModel.Bounds.minimumVerbosity)
    }
  }
}
