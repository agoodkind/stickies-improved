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

    public func resolveLibraryURL() throws -> URL {
        if let rootURLOverride {
            return rootURLOverride
        }

        // FileManager is accessed inline rather than stored so the struct stays
        // Sendable under Swift 6 strict concurrency.
        let fileManager = FileManager.default
        let ubiquityURL = fileManager.url(
            forUbiquityContainerIdentifier: iCloudContainerIdentifier
        )
        if let ubiquityURL {
            return
                ubiquityURL
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("Notes", isDirectory: true)
        }

        let appSupport = try fileManager.url(
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
}
