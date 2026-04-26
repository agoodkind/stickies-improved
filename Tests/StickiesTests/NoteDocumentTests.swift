@testable import StickiesImprovedCore
import XCTest

final class NoteDocumentTests: XCTestCase {
    func testTitleFallsBackToUntitled() {
        let document = NoteDocument(plainText: "")
        XCTAssertEqual(document.metadata.title, "Untitled")
    }

    func testTitleUsesFirstNonEmptyLine() {
        let document = NoteDocument(plainText: "\n\n Grocery list\nMilk")
        XCTAssertEqual(document.metadata.title, "Grocery list")
        XCTAssertEqual(document.metadata.excerpt, "Grocery list Milk")
    }
}
