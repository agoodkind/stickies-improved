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

    @Test func updateFontPersistsNameAndSize() async {
        let store = InMemoryNoteStore()
        let model = makeModel(store: store)
        let noteID = await model.createNote()

        model.updateFont(name: "Menlo-Regular", size: 18, for: noteID)

        await pollUntilFontSaved(store: store, id: noteID, expectedSize: 18)

        #expect(model.note(for: noteID)?.metadata.fontName == "Menlo-Regular")
        #expect(model.note(for: noteID)?.metadata.fontSize == 18)
        let saved = await store.document(for: noteID)
        #expect(saved?.metadata.fontName == "Menlo-Regular")
        #expect(saved?.metadata.fontSize == 18)
    }

    @Test func updateFontWithNilNameClearsToSystemFont() async {
        let store = InMemoryNoteStore()
        let model = makeModel(store: store)
        let noteID = await model.createNote()
        model.updateFont(name: "Menlo-Regular", size: 18, for: noteID)
        await pollUntilFontSaved(store: store, id: noteID, expectedSize: 18)

        model.updateFont(name: nil, size: 12, for: noteID)

        await pollUntilFontSaved(store: store, id: noteID, expectedSize: 12)
        #expect(model.note(for: noteID)?.metadata.fontName == nil)
        let saved = await store.document(for: noteID)
        #expect(saved?.metadata.fontName == nil)
        #expect(saved?.metadata.fontSize == 12)
    }

    @Test func updateFontColorPersistsHex() async {
        let store = InMemoryNoteStore()
        let model = makeModel(store: store)
        let noteID = await model.createNote()

        model.updateFontColor(hex: "#112233", for: noteID)

        await pollUntilFontColorSaved(store: store, id: noteID, expected: "#112233")

        #expect(model.note(for: noteID)?.metadata.fontColorHex == "#112233")
        let saved = await store.document(for: noteID)
        #expect(saved?.metadata.fontColorHex == "#112233")
    }

    private func pollUntilFontSaved(
        store: InMemoryNoteStore,
        id: NoteID,
        expectedSize: Double
    ) async {
        let maxAttempts = 200
        for _ in 0..<maxAttempts {
            let document = await store.document(for: id)
            if document?.metadata.fontSize == expectedSize {
                return
            }
            await Task.yield()
        }
    }

    private func pollUntilFontColorSaved(
        store: InMemoryNoteStore,
        id: NoteID,
        expected: String
    ) async {
        let maxAttempts = 200
        for _ in 0..<maxAttempts {
            let document = await store.document(for: id)
            if document?.metadata.fontColorHex == expected {
                return
            }
            await Task.yield()
        }
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
