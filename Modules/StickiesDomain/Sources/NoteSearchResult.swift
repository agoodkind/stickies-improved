//
//  NoteSearchResult.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

/// One hit from a full-text search across the note library. Carries enough to
/// render a result row and open the underlying note without re-reading disk:
/// the note id, its title, its color for the swatch, whether it lives in the
/// trash, and a short context snippet around the first match.
public struct NoteSearchResult: Equatable, Identifiable, Sendable {
    public var noteID: NoteID
    public var title: String
    public var color: NoteColor
    public var isTrashed: Bool
    public var snippet: String

    public init(
        noteID: NoteID,
        title: String,
        color: NoteColor,
        isTrashed: Bool,
        snippet: String
    ) {
        self.noteID = noteID
        self.title = title
        self.color = color
        self.isTrashed = isTrashed
        self.snippet = snippet
    }

    public var id: NoteID {
        noteID
    }
}
