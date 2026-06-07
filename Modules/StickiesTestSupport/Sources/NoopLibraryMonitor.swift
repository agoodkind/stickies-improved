//
//  NoopLibraryMonitor.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain

/// A `LibraryMonitoring` that records the change handler but never fires it, so
/// tests control disk-change behavior explicitly.
@preconcurrency
@MainActor
public final class NoopLibraryMonitor: LibraryMonitoring {
  public private(set) var didStart = false

  public init() {
    // No state to configure.
  }

  public func startMonitoring(rootURL _: URL, onChange _: () -> Void) {
    didStart = true
  }
}
