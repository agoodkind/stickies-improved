//
//  NoteMetadataTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Testing

@testable import StickiesImprovedCore

struct NoteMetadataTests {
    @Test func unknownFutureModeFallsBackSafely() throws {
        let jsonString = """
            {
              "id": "\(NoteID())",
              "mode": "markdown",
              "createdAt": "2026-04-25T21:00:00Z",
              "updatedAt": "2026-04-25T21:00:00Z",
              "title": "Draft",
              "excerpt": "Draft excerpt",
              "schemaVersion": 2
            }
            """
        let json = Data(jsonString.utf8)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(NoteMetadata.self, from: json)

        #expect(metadata.mode == .markdown)
        #expect(metadata.schemaVersion == 2)
    }
}
