//
//  UpdaterModel.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Observation
import StickiesDomain

@preconcurrency
@Observable
@MainActor
public final class UpdaterModel {
  private let controller: any UpdaterControlling

  public let isConfigured: Bool
  public private(set) var canCheckForUpdates: Bool
  public private(set) var automaticallyChecksForUpdates: Bool

  public init(controller: any UpdaterControlling) {
    self.controller = controller
    isConfigured = controller.isConfigured
    canCheckForUpdates = controller.canCheckForUpdates
    automaticallyChecksForUpdates = controller.automaticallyChecksForUpdates
    controller.observeStateChanges { [weak self] in
      self?.refreshFromController()
    }
  }

  public func checkForUpdates() {
    controller.checkForUpdates()
  }

  public func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
    controller.setAutomaticallyChecksForUpdates(enabled)
    refreshFromController()
  }

  private func refreshFromController() {
    canCheckForUpdates = controller.canCheckForUpdates
    automaticallyChecksForUpdates = controller.automaticallyChecksForUpdates
  }
}
