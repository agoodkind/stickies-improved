//
//  ExportFilename.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

/// Turns a note title into a filesystem-safe default name for the export panel.
/// The note title is free text, so characters a path component cannot hold are
/// replaced and an empty result falls back to a fixed placeholder.
public enum ExportFilename {
    public static let fallback = "Untitled"
    private static let maximumLength = 100
    private static let replacement: Character = "-"

    /// Characters that are illegal in a file name on macOS plus control
    /// characters, collapsed to a single dash so the name stays readable.
    private static let illegalCharacters: CharacterSet = {
        var set = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        set.formUnion(.controlCharacters)
        set.formUnion(.newlines)
        return set
    }()

    public static func sanitized(_ rawTitle: String) -> String {
        let scalars = rawTitle.unicodeScalars.map { scalar -> Character in
            if illegalCharacters.contains(scalar) {
                return replacement
            }
            return Character(scalar)
        }
        let replaced = String(scalars)
        let trimmed = replaced.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }
        return String(trimmed.prefix(maximumLength))
    }
}
