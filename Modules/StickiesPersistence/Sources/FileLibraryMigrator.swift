//
//  FileLibraryMigrator.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain
import os

/// Moves `.stickynote` packages between the local and iCloud roots when the user
/// changes the storage mode. The move is coordinated through `NSFileCoordinator`
/// because the iCloud root is shared with the sync daemon. Destination wins on
/// conflict: a package already present at the destination is left untouched and
/// its source copy is removed, so a switch never overwrites newer synced data.
///
/// An actor so the file work runs off the caller's executor; its synchronous
/// `migrate` satisfies the asynchronous `LibraryMigrating` requirement through
/// actor isolation.
public actor FileLibraryMigrator: LibraryMigrating {
    static let packageExtension = "stickynote"

    private let resolver: any StorageLocationResolving
    private let fileManager = FileManager.default
    private let logger: Logger

    public init(resolver: any StorageLocationResolving, loggerSubsystem: String) {
        self.resolver = resolver
        logger = Logger(subsystem: loggerSubsystem, category: "FileLibraryMigrator")
    }

    public func migrate(
        from sourceMode: StorageMode,
        to destinationMode: StorageMode
    ) throws {
        guard sourceMode != destinationMode else {
            return
        }
        guard let sourceURL = try url(for: sourceMode),
            let destinationURL = try url(for: destinationMode)
        else {
            // A nil root means the iCloud container is unavailable; there is
            // nothing to move between, so the switch is a no-op on disk.
            logger.error("Skipping migration: a storage root was unavailable")
            return
        }
        try moveLibrary(from: sourceURL, to: destinationURL)
    }

    private func url(for mode: StorageMode) throws -> URL? {
        switch mode {
        case .local:
            return try resolver.localLibraryURL()
        case .iCloud:
            return resolver.iCloudLibraryURL()
        }
    }

    /// Moves every package from `sourceURL` into `destinationURL`. A package whose
    /// name already exists at the destination is skipped and removed from the
    /// source so the destination copy wins. Returns without error when the source
    /// holds no packages.
    func moveLibrary(from sourceURL: URL, to destinationURL: URL) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            logger.debug("Migration source root is absent; nothing to move")
            return
        }
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let packages = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == Self.packageExtension }

        logger.debug("Migrating \(packages.count, privacy: .public) note package(s)")
        for package in packages {
            let target = destinationURL.appendingPathComponent(package.lastPathComponent)
            if fileManager.fileExists(atPath: target.path) {
                try coordinatedRemove(at: package)
            } else {
                try coordinatedMove(from: package, to: target)
            }
        }
    }

    private func coordinatedMove(from sourceURL: URL, to destinationURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var operationError: Error?
        coordinator.coordinate(
            writingItemAt: sourceURL,
            options: .forMoving,
            writingItemAt: destinationURL,
            options: .forReplacing,
            error: &coordinationError
        ) { readURL, writeURL in
            do {
                try fileManager.moveItem(at: readURL, to: writeURL)
            } catch {
                logger.error(
                    "Coordinated move failed: \(error.localizedDescription, privacy: .public)")
                operationError = error
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        if let operationError {
            throw operationError
        }
    }

    private func coordinatedRemove(at url: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var operationError: Error?
        coordinator.coordinate(
            writingItemAt: url,
            options: .forDeleting,
            error: &coordinationError
        ) { removeURL in
            do {
                try fileManager.removeItem(at: removeURL)
            } catch {
                logger.error(
                    "Coordinated remove failed: \(error.localizedDescription, privacy: .public)")
                operationError = error
            }
        }
        if let coordinationError {
            throw coordinationError
        }
        if let operationError {
            throw operationError
        }
    }
}
