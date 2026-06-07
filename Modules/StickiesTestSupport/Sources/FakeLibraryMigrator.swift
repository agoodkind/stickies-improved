//
//  FakeLibraryMigrator.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain

/// Records the storage-mode migrations it is asked to perform so orchestration
/// tests can assert that switching modes drives a migration without touching the
/// filesystem. The actor isolation matches the real migrator's `Sendable` shape.
public actor FakeLibraryMigrator: LibraryMigrating {
  public struct Migration: Sendable, Equatable {
    public let from: StorageMode
    public let to: StorageMode

    public init(from: StorageMode, to: StorageMode) {
      self.from = from
      self.to = to
    }
  }

  public private(set) var recordedMigrations: [Migration] = []

  public init() {
    // No dependencies; the recorder starts empty.
  }

  // A synchronous actor-isolated method satisfies the asynchronous protocol
  // requirement, which keeps the recorder free of an unused async/throws pair.
  public func migrate(from sourceMode: StorageMode, to destinationMode: StorageMode) {
    recordedMigrations.append(Migration(from: sourceMode, to: destinationMode))
  }
}
