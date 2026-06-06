//
//  NoteSearchRunner.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesDomain

/// Runs full-text search off the main actor. The caller snapshots the notes (cheap,
/// Sendable value types) on the main actor and awaits here, so matching and snippet work
/// for a large library never blocks the UI. This is the owned async boundary for search.
public actor NoteSearchRunner {
    public init() {
        // Stateless; isolation is the point.
    }

    public func search(
        active: [NoteDocument],
        trashed: [NoteDocument],
        query: String
    ) -> [NoteSearchResult] {
        NoteWorkspaceModel.searchResults(active: active, trashed: trashed, query: query)
    }
}
