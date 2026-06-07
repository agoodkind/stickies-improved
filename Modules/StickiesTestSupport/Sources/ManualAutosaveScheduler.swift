//
//  ManualAutosaveScheduler.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain

/// An `AutosaveScheduling` whose `sleep` returns immediately, so autosave fires
/// without a real delay and tests stay deterministic.
public struct ManualAutosaveScheduler: AutosaveScheduling {
  public init() {
    // No state to configure.
  }

  public func sleep(for _: Duration) {
    // Returns immediately so the debounced autosave runs without waiting.
  }
}
