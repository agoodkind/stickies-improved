import Foundation

public struct NoteMetadata: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var id: NoteID
    public var mode: NoteMode
    public var createdAt: Date
    public var updatedAt: Date
    public var title: String
    public var excerpt: String
    public var schemaVersion: Int

    public init(
        id: NoteID,
        mode: NoteMode,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        title: String = "Untitled",
        excerpt: String = "",
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.id = id
        self.mode = mode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.excerpt = excerpt
        self.schemaVersion = schemaVersion
    }
}
