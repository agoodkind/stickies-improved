//
//  ScratchDefaults.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 26/10/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import os

/// ScratchDefaults manages a test defaults suite in a temporary folder.
/// cfprefsd writes the suite's plist there instead of ~/Library/Preferences.
/// The instance deletes the folder on deallocation.
/// Callers must keep the instance alive for the whole test.
public final class ScratchDefaults {
  /// UserDefaults uses this absolute path as the suite name.
  public let suiteName: String
  public let defaults: UserDefaults
  private let directory: URL
  private let logger = Logger(
    subsystem: "io.goodkind.stickies-improved.tests", category: "ScratchDefaults")

  public init(label: String) throws {
    let directoryName = "\(label)-\(UUID().uuidString)"
    let scratchDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(directoryName, isDirectory: true)
    try FileManager.default.createDirectory(
      at: scratchDirectory,
      withIntermediateDirectories: true
    )
    let scratchSuiteName = scratchDirectory.appendingPathComponent("defaults").path
    guard let scratchDefaults = UserDefaults(suiteName: scratchSuiteName) else {
      throw ScratchDefaultsError.suiteUnavailable(scratchSuiteName)
    }
    directory = scratchDirectory
    suiteName = scratchSuiteName
    defaults = scratchDefaults
  }

  deinit {
    defaults.removePersistentDomain(forName: suiteName)
    do {
      try FileManager.default.removeItem(at: directory)
    } catch {
      logger.error(
        "Scratch defaults cleanup failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}

// MARK: - ScratchDefaultsError

/// ScratchDefaults throws this error when it cannot open the defaults suite.
public enum ScratchDefaultsError: Error {
  case suiteUnavailable(String)
}
