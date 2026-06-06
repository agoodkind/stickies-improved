//
//  NoteSearchResultsTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain
import StickiesTestSupport
import Testing

@testable import StickiesApplication

@MainActor
struct NoteSearchResultsTests {
    private func makeModel(store: InMemoryNoteStore) -> NoteWorkspaceModel {
        NoteWorkspaceModel(
            noteStore: store,
            libraryMonitor: NoopLibraryMonitor(),
            autosaveScheduler: ManualAutosaveScheduler(),
            libraryMigrator: FakeLibraryMigrator(),
            loggerSubsystem: "io.goodkind.stickies-improved.tests"
        )
    }

    private func makeDocument(
        body: String,
        color: NoteColor = .yellow,
        isTrashed: Bool = false
    ) -> NoteDocument {
        var metadata = NoteMetadata(id: NoteID(), mode: .plainText)
        metadata.colorName = color
        metadata.isTrashed = isTrashed
        var document = NoteDocument(metadata: metadata, plainText: body)
        document.metadata.isTrashed = isTrashed
        return document
    }

    @Test func emptyQueryReturnsNoResults() async {
        let store = InMemoryNoteStore()
        await store.save(makeDocument(body: "groceries milk eggs"))
        let model = makeModel(store: store)
        await model.refreshFromDisk()

        #expect(model.searchResults(for: "").isEmpty)
        #expect(model.searchResults(for: "   ").isEmpty)
    }

    @Test func bodyMatchReturnsResultWithSnippet() async throws {
        let store = InMemoryNoteStore()
        let prefix = String(repeating: "x", count: 60)
        await store.save(makeDocument(body: "\(prefix) needle in here", color: .blue))
        let model = makeModel(store: store)
        await model.refreshFromDisk()

        let results = model.searchResults(for: "needle")

        #expect(results.count == 1)
        let first = try #require(results.first)
        #expect(first.color == .blue)
        #expect(first.isTrashed == false)
        #expect(first.snippet.contains("needle"))
        #expect(first.snippet.hasPrefix("\u{2026}"))
    }

    @Test func searchSpansActiveAndTrashedNotes() async {
        let store = InMemoryNoteStore()
        await store.save(makeDocument(body: "shared keyword active body"))
        await store.save(makeDocument(body: "shared keyword trashed body", isTrashed: true))
        let model = makeModel(store: store)
        await model.refreshFromDisk()

        let results = model.searchResults(for: "keyword")

        #expect(results.count == 2)
        #expect(results.contains { $0.isTrashed == false })
        #expect(results.contains { $0.isTrashed == true })
    }

    @Test func titleOnlyMatchFallsBackToTitleSnippet() async throws {
        let store = InMemoryNoteStore()
        // The first line becomes the title; the query hits the title only.
        await store.save(makeDocument(body: "ProjectAlpha\nunrelated body content"))
        let model = makeModel(store: store)
        await model.refreshFromDisk()

        let results = model.searchResults(for: "ProjectAlpha")

        #expect(results.count == 1)
        let first = try #require(results.first)
        #expect(first.title == "ProjectAlpha")
        #expect(first.snippet.contains("ProjectAlpha"))
    }

    @Test func nonMatchingQueryReturnsEmpty() async {
        let store = InMemoryNoteStore()
        await store.save(makeDocument(body: "totally unrelated content"))
        let model = makeModel(store: store)
        await model.refreshFromDisk()

        #expect(model.searchResults(for: "absent").isEmpty)
    }
}
