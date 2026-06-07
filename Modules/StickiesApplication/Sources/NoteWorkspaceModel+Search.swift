//
//  NoteWorkspaceModel+Search.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain

extension NoteWorkspaceModel {
  /// Full-text search across every note, active and trashed, matching the title
  /// and the body case-insensitively. An empty or whitespace-only query returns
  /// no results so the manager keeps showing its normal sectioned list. Results
  /// keep the display order (active notes first, then trashed, each newest
  /// first) and carry a context snippet around the first body match, falling
  /// back to the title when only the title matched.
  public func searchResults(for query: String) -> [NoteSearchResult] {
    Self.searchResults(active: activeNotes, trashed: trashedNotes, query: query)
  }

  /// Pure, `nonisolated` search over snapshots so callers can run it off the main actor
  /// (the matching and snippet work is the part that can exceed a frame budget). The
  /// inputs are `Sendable` value types, so a background task can hold them safely.
  nonisolated public static func searchResults(
    active: [NoteDocument],
    trashed: [NoteDocument],
    query: String
  ) -> [NoteSearchResult] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return []
    }

    var results: [NoteSearchResult] = []
    for document in active {
      if let result = searchResult(for: document, query: trimmed) {
        results.append(result)
      }
    }
    for document in trashed {
      if let result = searchResult(for: document, query: trimmed) {
        results.append(result)
      }
    }
    return results
  }

  nonisolated private static func searchResult(
    for document: NoteDocument,
    query: String
  ) -> NoteSearchResult? {
    let bodyMatches = NoteSearch.matches(query: query, in: document.plainText)
    let titleMatches = NoteSearch.matches(query: query, in: document.metadata.title)
    guard bodyMatches || titleMatches else {
      return nil
    }

    let bodySnippet = NoteSearch.snippet(query: query, in: document.plainText)
    let snippet = bodySnippet ?? document.metadata.title
    return NoteSearchResult(
      noteID: document.id,
      title: document.metadata.title,
      color: document.metadata.colorName,
      isTrashed: document.metadata.isTrashed,
      snippet: snippet
    )
  }
}
