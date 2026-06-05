//
//  NoteDocument.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

public struct NoteDocument: Equatable, Identifiable, Sendable {
    private static let titleMaxLength = 40
    private static let excerptMaxLength = 120

    public var metadata: NoteMetadata
    public var plainText: String

    public init(metadata: NoteMetadata, plainText: String) {
        self.metadata = metadata
        self.plainText = plainText
        refreshDerivedFields()
    }

    public init(id: NoteID = NoteID(), mode: NoteMode = .plainText, plainText: String = "") {
        metadata = NoteMetadata(id: id, mode: mode)
        self.plainText = plainText
        refreshDerivedFields()
    }

    public var id: NoteID {
        metadata.id
    }

    public mutating func updatePlainText(_ plainText: String) {
        self.plainText = plainText
        metadata.updatedAt = .now
        refreshDerivedFields()
    }

    public mutating func refreshDerivedFields() {
        metadata.title = Self.makeTitle(from: plainText)
        metadata.excerpt = Self.makeExcerpt(from: plainText)
    }

    public static func makeTitle(from text: String) -> String {
        let firstLine =
            text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let title = firstLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "Untitled" : String(title.prefix(Self.titleMaxLength))
    }

    public static func makeExcerpt(from text: String) -> String {
        let collapsed =
            text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(Self.excerptMaxLength))
    }
}
