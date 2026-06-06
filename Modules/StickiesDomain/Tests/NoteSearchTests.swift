//
//  NoteSearchTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Testing

@testable import StickiesDomain

struct NoteSearchTests {
    @Test func matchInMiddleReturnsCenteredSnippet() throws {
        let prefix = String(repeating: "a", count: 60)
        let suffix = String(repeating: "b", count: 60)
        let body = "\(prefix) needle \(suffix)"

        let snippet = NoteSearch.snippet(query: "needle", in: body, contextRadius: 10)

        let unwrapped = try #require(snippet)
        #expect(unwrapped.contains("needle"))
        #expect(unwrapped.hasPrefix("\u{2026}"))
        #expect(unwrapped.hasSuffix("\u{2026}"))
    }

    @Test func noMatchReturnsNilSnippet() {
        #expect(NoteSearch.snippet(query: "missing", in: "some other text") == nil)
    }

    @Test func matchesIsCaseInsensitive() {
        #expect(NoteSearch.matches(query: "NEEDLE", in: "a needle in the body"))
        let snippet = NoteSearch.snippet(query: "NEEDLE", in: "a needle here")
        #expect(snippet?.contains("needle") == true)
    }

    @Test func snippetCollapsesWhitespaceAndNewlines() {
        let body = "lead\n\n\tmiddle    needle   tail"

        let snippet = NoteSearch.snippet(query: "needle", in: body, contextRadius: 40)

        #expect(snippet == "lead middle needle tail")
    }

    @Test func emptyOrWhitespaceQueryNeverMatches() {
        #expect(NoteSearch.matches(query: "", in: "anything") == false)
        #expect(NoteSearch.matches(query: "   ", in: "anything") == false)
        #expect(NoteSearch.snippet(query: "  ", in: "anything") == nil)
    }

    @Test func shortBodyReturnsSnippetWithoutEllipses() {
        let snippet = NoteSearch.snippet(query: "hi", in: "hi there", contextRadius: 40)

        #expect(snippet == "hi there")
    }
}
