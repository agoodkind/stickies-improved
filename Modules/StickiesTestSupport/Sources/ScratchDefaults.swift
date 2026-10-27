//
//  ScratchDefaults.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 26/10/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import os

/// ScratchDefaults creates a temporary folder and uses a path inside it
/// as the `UserDefaults` suite name.
/// Call `remove()` at the end of the test to report deletion errors.
/// `deinit` provides fallback cleanup if the test throws before that call.
public final class ScratchDefaults {
  /// UserDefaults uses this absolute path as the suite name.
  public let suiteName: String
  public let defaults: UserDefaults
  private let directory: URL
  private var isRemoved = false
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
      try FileManager.default.removeItem(at: scratchDirectory)
      throw ScratchDefaultsError.suiteUnavailable(scratchSuiteName)
    }
    directory = scratchDirectory
    suiteName = scratchSuiteName
    defaults = scratchDefaults
  }

  /// This method removes the persistent domain and deletes the temporary folder.
  /// It throws if folder deletion fails.
  /// A second call returns immediately.
  public func remove() throws {
    guard !isRemoved else {
      return
    }
    isRemoved = true
    logger.debug("Removing scratch defaults suite")
    defaults.removePersistentDomain(forName: suiteName)
    try FileManager.default.removeItem(at: directory)
  }

  deinit {
    do {
      try remove()
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
