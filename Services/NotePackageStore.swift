//
//  NotePackageStore.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import os

public enum NotePackageStoreError: LocalizedError {
    case missingMetadata(URL)
    case unsupportedMode(NoteMode)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedMode(mode):
            "Unsupported note mode: \(mode.rawValue)"
        case let .missingMetadata(url):
            "Missing metadata at \(url.path)"
        }
    }
}

// MARK: - NotePackageStore

public actor NotePackageStore {
    private let logger = Logger(subsystem: BuildConfig.appBundleID, category: "NotePackageStore")
    private let fileManager = FileManager.default
    private let packageExtension = "stickynote"
    private let rootURLOverride: URL?

    public init(rootURLOverride: URL? = nil) {
        self.rootURLOverride = rootURLOverride
    }

    public func ensureLibraryDirectory() throws -> URL {
        let rootURL = try resolvedLibraryURL()
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    public func loadAllDocuments() throws -> [NoteDocument] {
        let rootURL = try ensureLibraryDirectory()
        let urls = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return
            try urls
            .filter { $0.pathExtension == packageExtension }
            .map(loadDocument(packageURL:))
    }

    public func save(_ document: NoteDocument) throws {
        let packageURL = try packageURL(for: document.id)
        logger.debug("Saving note package at \(packageURL.path, privacy: .public)")
        try fileManager.createDirectory(at: packageURL, withIntermediateDirectories: true)

        let metadataURL = packageURL.appendingPathComponent("meta.json")
        let textURL = packageURL.appendingPathComponent(document.metadata.mode.contentFileName)
        let markdownURL = packageURL.appendingPathComponent("content.md")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        var metadata = document.metadata
        metadata.schemaVersion = NoteMetadata.currentSchemaVersion
        metadata.updatedAt = .now

        let metadataData = try encoder.encode(metadata)
        try coordinatedWrite(data: metadataData, to: metadataURL)

        switch metadata.mode {
        case .plainText:
            try coordinatedWrite(data: Data(document.plainText.utf8), to: textURL)
            if fileManager.fileExists(atPath: markdownURL.path) {
                try fileManager.removeItem(at: markdownURL)
            }
        case .markdown:
            throw NotePackageStoreError.unsupportedMode(.markdown)
        }
    }

    public func loadDocument(id: NoteID) throws -> NoteDocument {
        try loadDocument(packageURL: packageURL(for: id))
    }

    private func loadDocument(packageURL: URL) throws -> NoteDocument {
        let metadataURL = packageURL.appendingPathComponent("meta.json")
        let metadataData = try coordinatedRead(from: metadataURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var metadata = try decoder.decode(NoteMetadata.self, from: metadataData)

        let contentURL = packageURL.appendingPathComponent(metadata.mode.contentFileName)
        let contentData = try coordinatedRead(from: contentURL)

        switch metadata.mode {
        case .plainText:
            var document = NoteDocument(
                metadata: metadata,
                plainText: String(bytes: contentData, encoding: .utf8) ?? ""
            )
            document.refreshDerivedFields()
            return document
        case .markdown:
            metadata.mode = .plainText
            return NoteDocument(
                metadata: metadata,
                plainText: String(bytes: contentData, encoding: .utf8) ?? ""
            )
        }
    }

    private func packageURL(for noteID: NoteID) throws -> URL {
        try ensureLibraryDirectory()
            .appendingPathComponent(noteID.description)
            .appendingPathExtension(packageExtension)
    }

    private func resolvedLibraryURL() throws -> URL {
        if let rootURLOverride {
            return rootURLOverride
        }

        let ubiquityURL = fileManager.url(
            forUbiquityContainerIdentifier: BuildConfig.iCloudContainerIdentifier
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
            .appendingPathComponent(BuildConfig.appBundleID, isDirectory: true)
            .appendingPathComponent("Notes", isDirectory: true)
    }

    private func coordinatedRead(from url: URL) throws -> Data {
        let coordinator = NSFileCoordinator()
        var error: NSError?
        var result = Data()
        var readError: Error?
        coordinator.coordinate(readingItemAt: url, options: [], error: &error) { readURL in
            do {
                result = try Data(contentsOf: readURL)
            } catch {
                logger.error(
                    "Coordinated read failed: \(error.localizedDescription, privacy: .public)")
                readError = error
            }
        }

        if let error {
            throw error
        }
        if let readError {
            throw readError
        }
        return result
    }

    private func coordinatedWrite(data: Data, to url: URL) throws {
        let coordinator = NSFileCoordinator()
        var error: NSError?
        var writeError: Error?
        coordinator
            .coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
                do {
                    try data.write(to: writeURL, options: .atomic)
                } catch {
                    logger.error(
                        "Coordinated write failed: \(error.localizedDescription, privacy: .public)")
                    writeError = error
                }
            }

        if let error {
            throw error
        }
        if let writeError {
            throw writeError
        }
    }
}

// MARK: - NoteMode

extension NoteMode {
    var contentFileName: String {
        switch self {
        case .plainText:
            "content.txt"
        case .markdown:
            "content.md"
        }
    }
}
