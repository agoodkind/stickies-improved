//
//  FilePackageNoteStoreTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain
import Testing

@testable import StickiesPersistence

struct FilePackageNoteStoreTests {
    private func makeStore() throws -> FilePackageNoteStore {
        let resolver = StorageLocationResolver(
            iCloudContainerIdentifier: "unused.test.container",
            localFolderName: "test",
            rootURLOverride: try temporaryDirectory()
        )
        return FilePackageNoteStore(
            locationResolver: resolver,
            contentCodec: IdentityContentCodec(),
            loggerSubsystem: "io.goodkind.stickies-improved.tests"
        )
    }

    @Test func plainTextRoundTrip() async throws {
        let store = try makeStore()
        let noteID = NoteID()
        let document = NoteDocument(id: noteID, plainText: "hello world")

        try await store.save(document)
        let loaded = try await store.loadDocument(id: noteID)

        #expect(loaded.id == noteID)
        #expect(loaded.plainText == "hello world")
        #expect(loaded.metadata.mode == .plainText)
    }

    @Test func deleteRemovesDocument() async throws {
        let store = try makeStore()
        let noteID = NoteID()
        try await store.save(NoteDocument(id: noteID, plainText: "to delete"))

        try await store.delete(id: noteID)

        let remaining = try await store.loadAllDocuments()
        #expect(remaining.contains { $0.id == noteID } == false)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString,
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
