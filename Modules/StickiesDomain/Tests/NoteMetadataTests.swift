//
//  NoteMetadataTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Testing

@testable import StickiesDomain

struct NoteMetadataTests {
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

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

        let metadata = try makeDecoder().decode(NoteMetadata.self, from: json)

        #expect(metadata.mode == .markdown)
        #expect(metadata.schemaVersion == 2)
    }

    @Test func v1JSONDecodesWithSchemaV2Defaults() throws {
        // A v1 blob carries none of the schema-v2 keys, so each must fall back
        // to its default without throwing.
        let jsonString = """
            {
              "id": "\(NoteID())",
              "mode": "plain_text",
              "createdAt": "2026-04-25T21:00:00Z",
              "updatedAt": "2026-04-25T21:00:00Z",
              "title": "Old Note",
              "excerpt": "Old excerpt",
              "schemaVersion": 1
            }
            """
        let json = Data(jsonString.utf8)

        let metadata = try makeDecoder().decode(NoteMetadata.self, from: json)

        #expect(metadata.schemaVersion == 1)
        #expect(metadata.colorName == .yellow)
        #expect(metadata.fontName == nil)
        #expect(metadata.fontSize == 12)
        #expect(metadata.fontColorHex == nil)
        #expect(metadata.frame == nil)
        #expect(metadata.collapsed == false)
        #expect(metadata.expandedHeight == nil)
        #expect(metadata.isTrashed == false)
    }

    @Test func v2MetadataRoundTrips() throws {
        let original = NoteMetadata(
            id: NoteID(),
            mode: .plainText,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
            title: "Round Trip",
            excerpt: "Round trip excerpt",
            colorName: .blue,
            fontName: "Menlo",
            fontSize: 18,
            fontColorHex: "#112233",
            frame: NoteFrame(x: 10, y: 20, width: 300, height: 250),
            collapsed: true,
            expandedHeight: 480,
            isTrashed: true
        )

        let encoded = try makeEncoder().encode(original)
        let decoded = try makeDecoder().decode(NoteMetadata.self, from: encoded)

        #expect(decoded == original)
    }
}
