//
//  NoteSearch.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

/// Pure, UI-free full-text search primitives. `matches` answers whether a query
/// occurs in a body, and `snippet` returns a short context window around the
/// first occurrence with whitespace collapsed and ellipses where it was cut.
/// Both are case-insensitive and live in Domain so they are unit-testable
/// without AppKit, SwiftUI, or disk.
public enum NoteSearch {
  /// Characters on each side of the match included in a snippet by default.
  public static let defaultContextRadius = 40

  private static let ellipsis = "\u{2026}"

  /// Case-insensitive substring test. A query that is empty or only whitespace
  /// never matches, so the manager falls back to its sectioned list instead.
  public static func matches(query: String, in body: String) -> Bool {
    firstMatchRange(of: query, in: body) != nil
  }

  /// Builds a context snippet around the first case-insensitive occurrence of
  /// `query` in `body`. Returns nil when there is no match (including for an
  /// empty or whitespace-only query). The snippet spans about `contextRadius`
  /// characters on each side of the match, collapses every run of whitespace
  /// and newlines into a single space, trims the ends, and prepends or appends
  /// an ellipsis when the window starts after the body begins or ends before
  /// the body ends.
  public static func snippet(
    query: String,
    in body: String,
    contextRadius: Int = defaultContextRadius
  ) -> String? {
    guard let matchRange = firstMatchRange(of: query, in: body) else {
      return nil
    }

    let lowerBound = body.index(
      matchRange.lowerBound,
      offsetBy: -contextRadius,
      limitedBy: body.startIndex
    )
    let windowStart = lowerBound ?? body.startIndex

    let upperBound = body.index(
      matchRange.upperBound,
      offsetBy: contextRadius,
      limitedBy: body.endIndex
    )
    let windowEnd = upperBound ?? body.endIndex

    let truncatedHead = windowStart > body.startIndex
    let truncatedTail = windowEnd < body.endIndex

    let window = String(body[windowStart..<windowEnd])
    let collapsed = collapseWhitespace(in: window)

    // A window made entirely of whitespace collapses to an empty string; if
    // that happens there is nothing meaningful to show around the match.
    guard !collapsed.isEmpty else {
      return nil
    }

    var snippet = collapsed
    if truncatedHead {
      snippet = ellipsis + snippet
    }
    if truncatedTail {
      snippet += ellipsis
    }
    return snippet
  }

  private static func firstMatchRange(
    of query: String,
    in body: String
  ) -> Range<String.Index>? {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else {
      return nil
    }
    return body.range(of: trimmedQuery, options: .caseInsensitive)
  }

  /// Replaces every maximal run of whitespace or newline characters with a
  /// single space, then trims the leading and trailing space the runs leave.
  private static func collapseWhitespace(in text: String) -> String {
    var collapsed = ""
    collapsed.reserveCapacity(text.count)
    var previousWasWhitespace = false
    for character in text {
      if character.isWhitespace {
        if !previousWasWhitespace {
          collapsed.append(" ")
        }
        previousWasWhitespace = true
      } else {
        collapsed.append(character)
        previousWasWhitespace = false
      }
    }
    return collapsed.trimmingCharacters(in: .whitespaces)
  }
}
