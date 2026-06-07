//
//  LibraryMigrating.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

/// Moves every note package from the root backing one storage mode to the root
/// backing another, so switching between local and iCloud carries the existing
/// library across rather than stranding it under the old root.
public protocol LibraryMigrating: Sendable {
  func migrate(from sourceMode: StorageMode, to destinationMode: StorageMode) async throws
}
