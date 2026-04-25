import XCTest
@testable import PlainStickiesCore

final class NotePackageStoreTests: XCTestCase {
    func testPlainTextRoundTrip() async throws {
        let packageStore = NotePackageStore(rootURLOverride: temporaryDirectory())
        let noteID = NoteID()
        let document = NoteDocument(id: noteID, plainText: "hello world")

        try await packageStore.save(document)
        let loaded = try await packageStore.loadDocument(id: noteID)

        XCTAssertEqual(loaded.id, noteID)
        XCTAssertEqual(loaded.plainText, "hello world")
        XCTAssertEqual(loaded.metadata.mode, .plainText)
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
