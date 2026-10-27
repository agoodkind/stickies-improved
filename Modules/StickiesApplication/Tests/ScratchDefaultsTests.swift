//
//  ScratchDefaultsTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 27/10/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesTestSupport
import Testing

struct ScratchDefaultsTests {
  @Test func sweepDeletesFolderOfEndedProcessAndKeepsOwnFolder() throws {
    let endedProcess = Process()
    endedProcess.executableURL = URL(fileURLWithPath: "/usr/bin/true")
    try endedProcess.run()
    endedProcess.waitUntilExit()
    let endedProcessID = endedProcess.processIdentifier

    let staleFolder = ScratchDefaults.scratchRoot
      .appendingPathComponent(String(endedProcessID), isDirectory: true)
      .appendingPathComponent("stale-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: staleFolder, withIntermediateDirectories: true)
    let stalePlist = staleFolder.appendingPathComponent("defaults.plist")
    try Data("stale defaults".utf8).write(to: stalePlist)

    let scratch = try ScratchDefaults(label: "scratch-defaults-tests")
    let ownFolder = URL(fileURLWithPath: scratch.suiteName).deletingLastPathComponent()
    try ScratchDefaults.sweepStaleFolders()

    #expect(!FileManager.default.fileExists(atPath: staleFolder.path))
    #expect(
      !FileManager.default.fileExists(atPath: staleFolder.deletingLastPathComponent().path))
    #expect(FileManager.default.fileExists(atPath: ownFolder.path))

    try scratch.remove()

    #expect(!FileManager.default.fileExists(atPath: ownFolder.path))
  }
}
