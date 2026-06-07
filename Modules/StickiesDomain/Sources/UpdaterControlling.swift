//
//  UpdaterControlling.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

@preconcurrency
@MainActor
public protocol UpdaterControlling {
  /// True when a real updater is running with a feed URL and public key embedded, so
  /// update UI can disable itself in unsigned or local builds.
  var isConfigured: Bool { get }
  /// True once the updater has started and is ready to check, mirroring Sparkle's
  /// `canCheckForUpdates`.
  var canCheckForUpdates: Bool { get }
  /// The live automatic-update preference backing the About and Settings toggle.
  var automaticallyChecksForUpdates: Bool { get }

  func checkForUpdates()
  func setAutomaticallyChecksForUpdates(_ enabled: Bool)
  /// Registers a callback invoked on the main actor whenever `canCheckForUpdates` or
  /// `automaticallyChecksForUpdates` changes, so an `@Observable` model can refresh.
  func observeStateChanges(_ onChange: @escaping @MainActor () -> Void)
}
