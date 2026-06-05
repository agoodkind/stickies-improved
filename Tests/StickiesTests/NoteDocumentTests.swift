//
//  NoteDocumentTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Testing

@testable import StickiesImprovedCore

struct NoteDocumentTests {
    @Test func titleFallsBackToUntitled() {
        let document = NoteDocument(plainText: "")
        #expect(document.metadata.title == "Untitled")
    }

    @Test func titleUsesFirstNonEmptyLine() {
        let document = NoteDocument(plainText: "\n\n Grocery list\nMilk")
        #expect(document.metadata.title == "Grocery list")
        #expect(document.metadata.excerpt == "Grocery list Milk")
    }
}
