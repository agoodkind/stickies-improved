//
//  StorageMode.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

/// Where the note library lives on disk. `local` keeps packages under
/// Application Support; `iCloud` keeps them in the ubiquity container so the
/// library syncs across devices.
public enum StorageMode: String, Codable, CaseIterable, Sendable {
  // The wire value is pinned explicitly because the linter requires a raw value
  // on camel-cased Codable cases, and it must differ from the case name to stay
  // clear of the redundant-raw-value rule.
  case iCloud = "icloud"
  case local

  /// The persisted-preference key, defined here so the resolver in Persistence
  /// and the preferences model in Application read the same default without
  /// duplicating the string.
  public static let defaultsKey = "storageMode"

  /// Matches the historical resolver behavior of preferring the ubiquity
  /// container when it is available, so an install with no stored preference
  /// keeps resolving the same root it always did.
  public static let `default`: StorageMode = .iCloud
}
