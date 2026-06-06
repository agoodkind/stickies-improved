//
//  FilePackageNoteStore.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain
import os

public enum FilePackageNoteStoreError: LocalizedError {
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

// MARK: - FilePackageNoteStore

public actor FilePackageNoteStore: NoteStore {
    private let logger: Logger
    private let fileManager = FileManager.default
    private let packageExtension = "stickynote"
    private let locationResolver: any StorageLocationResolving
    private let contentCodec: any ContentCodec
    private let crdtFileName = "note.automerge"

    public init(
        locationResolver: any StorageLocationResolving,
        contentCodec: any ContentCodec,
        loggerSubsystem: String
    ) {
        self.locationResolver = locationResolver
        self.contentCodec = contentCodec
        logger = Logger(subsystem: loggerSubsystem, category: "FilePackageNoteStore")
    }

    public func ensureLibraryDirectory() throws -> URL {
        let rootURL = try locationResolver.resolveLibraryURL()
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
        let crdtURL = packageURL.appendingPathComponent(crdtFileName)

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
            let encoded = try contentCodec.encode(document.plainText)
            try coordinatedWrite(data: encoded, to: textURL)
            if fileManager.fileExists(atPath: markdownURL.path) {
                try fileManager.removeItem(at: markdownURL)
            }
        case .markdown:
            throw FilePackageNoteStoreError.unsupportedMode(.markdown)
        }

        // The Automerge document is the merge-aware source of truth; meta.json and
        // content.txt above are its human-readable mirror. Write it when present so a note
        // promoted to a CRDT keeps its full edit history across saves.
        if let crdtData = document.crdtData {
            try coordinatedWrite(data: crdtData, to: crdtURL)
        }
    }

    public func loadDocument(id: NoteID) throws -> NoteDocument {
        try loadDocument(packageURL: packageURL(for: id))
    }

    public func delete(id: NoteID) throws {
        let packageURL = try packageURL(for: id)
        guard fileManager.fileExists(atPath: packageURL.path) else { return }
        try coordinatedRemove(at: packageURL)
    }

    private func loadDocument(packageURL: URL) throws -> NoteDocument {
        let metadataURL = packageURL.appendingPathComponent("meta.json")
        let metadataData = try coordinatedRead(from: metadataURL)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var metadata = try decoder.decode(NoteMetadata.self, from: metadataData)

        let contentURL = packageURL.appendingPathComponent(metadata.mode.contentFileName)
        let contentData = try coordinatedRead(from: contentURL)
        let decodedText = try contentCodec.decode(contentData)

        // Read the Automerge document if the package carries one. A legacy note without it
        // loads with `crdtData == nil`, which the model treats as "seed a CRDT on first use".
        let crdtURL = packageURL.appendingPathComponent(crdtFileName)
        let crdtData =
            fileManager.fileExists(atPath: crdtURL.path)
            ? try coordinatedRead(from: crdtURL)
            : nil

        switch metadata.mode {
        case .plainText:
            var document = NoteDocument(
                metadata: metadata, plainText: decodedText, crdtData: crdtData
            )
            document.refreshDerivedFields()
            return document
        case .markdown:
            metadata.mode = .plainText
            return NoteDocument(metadata: metadata, plainText: decodedText, crdtData: crdtData)
        }
    }

    private func packageURL(for noteID: NoteID) throws -> URL {
        try ensureLibraryDirectory()
            .appendingPathComponent(noteID.description)
            .appendingPathExtension(packageExtension)
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

    private func coordinatedRemove(at url: URL) throws {
        let coordinator = NSFileCoordinator()
        var error: NSError?
        var removeError: Error?
        coordinator
            .coordinate(writingItemAt: url, options: .forDeleting, error: &error) { removeURL in
                do {
                    try fileManager.removeItem(at: removeURL)
                } catch {
                    logger.error(
                        "Coordinated remove failed: \(error.localizedDescription, privacy: .public)"
                    )
                    removeError = error
                }
            }

        if let error {
            throw error
        }
        if let removeError {
            throw removeError
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
