import XCTest
@testable import StickiesImprovedCore

final class NoteMetadataTests: XCTestCase {
    func testUnknownFutureModeFallsBackSafely() throws {
        let json = """
        {
          "id": "\(NoteID())",
          "mode": "markdown",
          "createdAt": "2026-04-25T21:00:00Z",
          "updatedAt": "2026-04-25T21:00:00Z",
          "title": "Draft",
          "excerpt": "Draft excerpt",
          "schemaVersion": 2
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let metadata = try decoder.decode(NoteMetadata.self, from: json)

        XCTAssertEqual(metadata.mode, .markdown)
        XCTAssertEqual(metadata.schemaVersion, 2)
    }
}
