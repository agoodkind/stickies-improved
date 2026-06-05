//
//  NoteWorkspaceModelTests.swift
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
struct NoteWorkspaceModelTests {
    private func makeModel(store: InMemoryNoteStore) -> NoteWorkspaceModel {
        NoteWorkspaceModel(
            noteStore: store,
            libraryMonitor: NoopLibraryMonitor(),
            autosaveScheduler: ManualAutosaveScheduler(),
            loggerSubsystem: "io.goodkind.stickies-improved.tests"
        )
    }

    @Test func createNoteReturnsRetrievableNote() async {
        let store = InMemoryNoteStore()
        let model = makeModel(store: store)

        let noteID = await model.createNote()

        #expect(model.note(for: noteID) != nil)
        #expect(model.note(for: noteID)?.id == noteID)
    }

    @Test func autosaveWritesEditedNoteToStore() async throws {
        let store = InMemoryNoteStore()
        let model = makeModel(store: store)
        let noteID = await model.createNote()

        model.updatePlainText("edited body", for: noteID)

        // The manual scheduler returns immediately, so the debounced autosave
        // task runs without a real delay; yield until the store reflects it.
        await pollUntilSaved(store: store, id: noteID, expected: "edited body")

        let saved = try await store.loadDocument(id: noteID)
        #expect(saved.plainText == "edited body")
    }

    @Test func updateColorPersistsAndReflectsInNote() async {
        let store = InMemoryNoteStore()
        let model = makeModel(store: store)
        let noteID = await model.createNote()

        model.updateColor(.blue, for: noteID)

        await pollUntilColorSaved(store: store, id: noteID, expected: .blue)

        #expect(model.note(for: noteID)?.metadata.colorName == .blue)
        let saved = await store.document(for: noteID)
        #expect(saved?.metadata.colorName == .blue)
    }

    private func pollUntilSaved(
        store: InMemoryNoteStore,
        id: NoteID,
        expected: String
    ) async {
        let maxAttempts = 200
        for _ in 0..<maxAttempts {
            let document = await store.document(for: id)
            if document?.plainText == expected {
                return
            }
            await Task.yield()
        }
    }

    private func pollUntilColorSaved(
        store: InMemoryNoteStore,
        id: NoteID,
        expected: NoteColor
    ) async {
        let maxAttempts = 200
        for _ in 0..<maxAttempts {
            let document = await store.document(for: id)
            if document?.metadata.colorName == expected {
                return
            }
            await Task.yield()
        }
    }
}
