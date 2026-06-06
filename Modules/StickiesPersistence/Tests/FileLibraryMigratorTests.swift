//
//  FileLibraryMigratorTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain
import Testing

@testable import StickiesPersistence

struct FileLibraryMigratorTests {
    private let packageExtension = "stickynote"

    private func makeMigrator() throws -> FileLibraryMigrator {
        let resolver = StorageLocationResolver(
            iCloudContainerIdentifier: "unused.test.container",
            localFolderName: "test",
            rootURLOverride: try makeTemporaryDirectory()
        )
        return FileLibraryMigrator(
            resolver: resolver,
            loggerSubsystem: "io.goodkind.stickies-improved.tests"
        )
    }

    @Test func movesPackagesAndDestinationWinsOnConflict() async throws {
        let migrator = try makeMigrator()
        let sourceRoot = try makeTemporaryDirectory()
        let destinationRoot = try makeTemporaryDirectory()

        try makePackage(named: "a", in: sourceRoot, marker: "source-a")
        try makePackage(named: "b", in: destinationRoot, marker: "dest-b")
        try makePackage(named: "c", in: sourceRoot, marker: "source-c")
        try makePackage(named: "c", in: destinationRoot, marker: "dest-c")

        try await migrator.moveLibrary(from: sourceRoot, to: destinationRoot)

        // The non-conflicting source package moved across.
        #expect(packageExists(named: "a", in: destinationRoot))
        // The destination-only package stayed put.
        #expect(packageExists(named: "b", in: destinationRoot))
        // The conflict kept the destination copy untouched.
        #expect(try marker(named: "c", in: destinationRoot) == "dest-c")
        // The source no longer holds any packages.
        let remaining = try FileManager.default.contentsOfDirectory(
            at: sourceRoot,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == packageExtension }
        #expect(remaining.isEmpty)
    }

    @Test func missingSourceRootIsANoOp() async throws {
        let migrator = try makeMigrator()
        let destinationRoot = try makeTemporaryDirectory()
        let missingSource = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try await migrator.moveLibrary(from: missingSource, to: destinationRoot)

        let contents = try FileManager.default.contentsOfDirectory(
            at: destinationRoot,
            includingPropertiesForKeys: nil
        )
        #expect(contents.isEmpty)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makePackage(named name: String, in root: URL, marker: String) throws {
        let packageURL = root.appendingPathComponent(name).appendingPathExtension(packageExtension)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
        let contentURL = packageURL.appendingPathComponent("content.txt")
        let created = FileManager.default.createFile(
            atPath: contentURL.path,
            contents: Data(marker.utf8)
        )
        #expect(created)
    }

    private func packageURL(named name: String, in root: URL) -> URL {
        root.appendingPathComponent(name).appendingPathExtension(packageExtension)
    }

    private func packageExists(named name: String, in root: URL) -> Bool {
        FileManager.default.fileExists(atPath: packageURL(named: name, in: root).path)
    }

    private func marker(named name: String, in root: URL) throws -> String {
        let contentURL = packageURL(named: name, in: root).appendingPathComponent("content.txt")
        let data = try Data(contentsOf: contentURL)
        guard let text = String(bytes: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return text
    }
}
