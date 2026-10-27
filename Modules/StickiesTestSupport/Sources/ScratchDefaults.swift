//
//  ScratchDefaults.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 26/10/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import os

/// ScratchDefaults stores test defaults in separate temporary folders.
/// Each folder uses the layout `scratchRoot/<process ID>/<label>-<UUID>/`.
/// Every instance sweeps folders from processes that
/// no longer exist.
/// Call `remove()` at the end of the test to report deletion errors.
/// `deinit` provides fallback cleanup if the test throws before that call.
public final class ScratchDefaults {
  /// UserDefaults uses this absolute path as the suite name.
  public let suiteName: String
  public let defaults: UserDefaults
  private let directory: URL
  private var isRemoved = false

  private static let rootFolderName = "io.goodkind.stickies-improved.scratch-defaults"
  private static let logger = Logger(
    subsystem: "io.goodkind.stickies-improved.tests", category: "ScratchDefaults")
  private static let folderLock = NSLock()

  /// Scratch folders share the temporary folder's
  /// `io.goodkind.stickies-improved.scratch-defaults` subfolder.
  public static var scratchRoot: URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(rootFolderName, isDirectory: true)
  }

  public init(label: String) throws {
    Self.folderLock.lock()
    defer { Self.folderLock.unlock() }
    try Self.sweepStaleFolders()
    let processFolder = Self.processFolder(processID: ProcessInfo.processInfo.processIdentifier)
    let directoryName = "\(label)-\(UUID().uuidString)"
    let scratchDirectory = processFolder.appendingPathComponent(directoryName, isDirectory: true)
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

  /// This method deletes the instance's scratch folder and then deletes its
  /// process folder if that folder is empty.
  /// A static lock serializes folder creation and empty process folder deletion.
  /// It throws if folder deletion fails, and a second call returns immediately.
  public func remove() throws {
    guard !isRemoved else {
      return
    }
    isRemoved = true
    Self.logger.debug("Removing scratch defaults suite")
    defaults.removePersistentDomain(forName: suiteName)
    Self.folderLock.lock()
    defer { Self.folderLock.unlock() }
    try FileManager.default.removeItem(at: directory)
    try Self.removeProcessFolderIfEmpty(directory.deletingLastPathComponent())
  }

  /// This method deletes process folders when `kill(pid, 0)` fails with `ESRCH`.
  /// It preserves folders for running processes, including the current process,
  /// and skips entries that do not use a process ID as their name.
  /// It logs each path at info level before attempting deletion.
  /// It counts an already missing entry as swept and logs its path at notice level.
  /// It throws `ScratchDefaultsError.sweepFailed(path:reason:)` for other deletion errors.
  private static func sweepStaleFolders() throws {
    let root = scratchRoot
    guard FileManager.default.fileExists(atPath: root.path) else {
      return
    }
    let entries = try FileManager.default.contentsOfDirectory(
      at: root, includingPropertiesForKeys: nil)
    let currentProcessID = ProcessInfo.processInfo.processIdentifier
    for entry in entries {
      guard let processID = Int32(entry.lastPathComponent),
        processID != currentProcessID,
        !isProcessRunning(processID)
      else {
        continue
      }
      logger.info("Deleting stale scratch folder \(entry.path, privacy: .public)")
      do {
        try FileManager.default.removeItem(at: entry)
      } catch let cocoaError as CocoaError
        where cocoaError.code == .fileNoSuchFile || cocoaError.code == .fileReadNoSuchFile
      {
        logger.notice("Stale scratch folder already deleted \(entry.path, privacy: .public)")
      } catch {
        throw ScratchDefaultsError.sweepFailed(
          path: entry.path, reason: error.localizedDescription)
      }
    }
  }

  deinit {
    do {
      try remove()
    } catch {
      Self.logger.error(
        "Scratch defaults cleanup failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private static func processFolder(processID: Int32) -> URL {
    scratchRoot.appendingPathComponent(String(processID), isDirectory: true)
  }

  private static func removeProcessFolderIfEmpty(_ folder: URL) throws {
    let remaining = try FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: nil)
    guard remaining.isEmpty else {
      return
    }
    logger.debug("Deleting empty scratch process folder \(folder.path, privacy: .public)")
    try FileManager.default.removeItem(at: folder)
  }

  /// The method returns false only when `kill(processID, 0)` fails with `ESRCH`.
  /// It returns true on success or any other error.
  private static func isProcessRunning(_ processID: Int32) -> Bool {
    if kill(processID, 0) == 0 {
      return true
    }
    return errno != ESRCH
  }
}

// MARK: - ScratchDefaultsError

/// ScratchDefaultsError reports failures from scratch defaults operations.
/// A sweep failure includes the path and the underlying error text.
public enum ScratchDefaultsError: Error {
  case suiteUnavailable(String)
  case sweepFailed(path: String, reason: String)
}
