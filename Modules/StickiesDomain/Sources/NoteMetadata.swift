//
//  NoteMetadata.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

public struct NoteMetadata: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    // Public so these named defaults can appear in the public initializer's
    // default argument values, which are evaluated at the call site.
    public enum Default {
        public static let title = "Untitled"
        public static let fontSize: Double = 12
        public static let collapsed = false
        public static let isTrashed = false
    }

    public var id: NoteID
    public var mode: NoteMode
    public var createdAt: Date
    public var updatedAt: Date
    public var title: String
    public var excerpt: String
    public var schemaVersion: Int

    // Schema v2 additions. Each has a Codable default so v1 JSON without these
    // keys still decodes through the custom `init(from:)` below.
    public var colorName: NoteColor
    public var fontName: String?
    public var fontSize: Double
    public var fontColorHex: String?
    public var frame: NoteFrame?
    public var collapsed: Bool
    public var expandedHeight: Double?
    public var isTrashed: Bool

    public init(
        id: NoteID,
        mode: NoteMode,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        title: String = Default.title,
        excerpt: String = "",
        schemaVersion: Int = currentSchemaVersion,
        colorName: NoteColor = .default,
        fontName: String? = nil,
        fontSize: Double = Default.fontSize,
        fontColorHex: String? = nil,
        frame: NoteFrame? = nil,
        collapsed: Bool = Default.collapsed,
        expandedHeight: Double? = nil,
        isTrashed: Bool = Default.isTrashed
    ) {
        self.id = id
        self.mode = mode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.excerpt = excerpt
        self.schemaVersion = schemaVersion
        self.colorName = colorName
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontColorHex = fontColorHex
        self.frame = frame
        self.collapsed = collapsed
        self.expandedHeight = expandedHeight
        self.isTrashed = isTrashed
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case mode
        case createdAt
        case updatedAt
        case title
        case excerpt
        case schemaVersion
        case colorName
        case fontName
        case fontSize
        case fontColorHex
        case frame
        case collapsed
        case expandedHeight
        case isTrashed
    }

    // Decode v1 JSON (which lacks the v2 keys) by falling back to defaults for
    // every field added in schema v2, so old notes keep loading after the bump.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(NoteID.self, forKey: .id)
        mode = try container.decode(NoteMode.self, forKey: .mode)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? Default.title
        excerpt = try container.decodeIfPresent(String.self, forKey: .excerpt) ?? ""
        schemaVersion =
            try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        colorName = try container.decodeIfPresent(NoteColor.self, forKey: .colorName) ?? .default
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName)
        fontSize =
            try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? Default.fontSize
        fontColorHex = try container.decodeIfPresent(String.self, forKey: .fontColorHex)
        frame = try container.decodeIfPresent(NoteFrame.self, forKey: .frame)
        collapsed =
            try container.decodeIfPresent(Bool.self, forKey: .collapsed) ?? Default.collapsed
        expandedHeight = try container.decodeIfPresent(Double.self, forKey: .expandedHeight)
        isTrashed =
            try container.decodeIfPresent(Bool.self, forKey: .isTrashed) ?? Default.isTrashed
    }
}
