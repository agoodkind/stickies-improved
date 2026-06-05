//
//  NotePackageStoreTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Testing

@testable import StickiesImprovedCore

struct NotePackageStoreTests {
    @Test func plainTextRoundTrip() async throws {
        let packageStore = NotePackageStore(rootURLOverride: try temporaryDirectory())
        let noteID = NoteID()
        let document = NoteDocument(id: noteID, plainText: "hello world")

        try await packageStore.save(document)
        let loaded = try await packageStore.loadDocument(id: noteID)

        #expect(loaded.id == noteID)
        #expect(loaded.plainText == "hello world")
        #expect(loaded.metadata.mode == .plainText)
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
