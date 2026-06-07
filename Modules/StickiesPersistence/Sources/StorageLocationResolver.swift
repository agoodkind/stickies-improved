//
//  StorageLocationResolver.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain

public struct StorageLocationResolver: StorageLocationResolving {
  private let iCloudContainerIdentifier: String
  private let localFolderName: String
  private let rootURLOverride: URL?

  public init(
    iCloudContainerIdentifier: String,
    localFolderName: String,
    rootURLOverride: URL? = nil
  ) {
    self.iCloudContainerIdentifier = iCloudContainerIdentifier
    self.localFolderName = localFolderName
    self.rootURLOverride = rootURLOverride
  }

  /// The active root follows the persisted storage mode. An iCloud preference
  /// falls back to the local root when the ubiquity container is unavailable,
  /// so the app never fails to resolve a usable directory.
  public func resolveLibraryURL() throws -> URL {
    if let rootURLOverride {
      return rootURLOverride
    }

    switch Self.persistedMode() {
    case .iCloud:
      return try iCloudLibraryURL() ?? localLibraryURL()
    case .local:
      return try localLibraryURL()
    }
  }

  public func localLibraryURL() throws -> URL {
    if let rootURLOverride {
      return rootURLOverride
    }

    // FileManager is accessed inline rather than stored so the struct stays
    // Sendable under Swift 6 strict concurrency.
    let appSupport = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )

    return
      appSupport
      .appendingPathComponent(localFolderName, isDirectory: true)
      .appendingPathComponent("Notes", isDirectory: true)
  }

  public func iCloudLibraryURL() -> URL? {
    let ubiquityURL = FileManager.default.url(
      forUbiquityContainerIdentifier: iCloudContainerIdentifier
    )
    guard let ubiquityURL else {
      return nil
    }
    return
      ubiquityURL
      .appendingPathComponent("Documents", isDirectory: true)
      .appendingPathComponent("Notes", isDirectory: true)
  }

  /// Reads the persisted storage mode from the standard defaults, matching the
  /// suite the preferences model writes, and falls back to the historical
  /// iCloud-preferred default when no preference was ever stored.
  private static func persistedMode() -> StorageMode {
    let defaults = UserDefaults.standard
    guard let raw = defaults.string(forKey: StorageMode.defaultsKey),
      let mode = StorageMode(rawValue: raw)
    else {
      return .default
    }
    return mode
  }
}
