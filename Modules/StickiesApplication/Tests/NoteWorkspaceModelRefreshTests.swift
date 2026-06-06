//
//  NoteWorkspaceModelRefreshTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 06/06/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain
import StickiesTestSupport
import Testing

@testable import StickiesApplication

/// Covers `refreshFromDisk`'s merge policy. Our own debounced autosave surfaces back
/// through the library monitor as a reload, so the reload must not clobber text the user
/// just typed, while a genuinely newer external file must still be imported.
@MainActor
struct NoteWorkspaceModelRefreshTests {
    private func makeModel(store: InMemoryNoteStore) -> NoteWorkspaceModel {
        NoteWorkspaceModel(
            noteStore: store,
            libraryMonitor: NoopLibraryMonitor(),
            autosaveScheduler: ManualAutosaveScheduler(),
            libraryMigrator: FakeLibraryMigrator(),
            loggerSubsystem: "io.goodkind.stickies-improved.tests"
        )
    }

    @Test func refreshFromDiskKeepsNewerInMemoryTextOverStaleFile() async {
        let store = InMemoryNoteStore()
        let model = makeModel(store: store)
        let noteID = await model.createNote()

        model.updatePlainText("fresh in-memory text", for: noteID)
        await pollUntilSaved(store: store, id: noteID, expected: "fresh in-memory text")

        guard let memoryUpdatedAt = model.note(for: noteID)?.metadata.updatedAt else {
            Issue.record("note missing after edit")
            return
        }
        let staleMetadata = NoteMetadata(
            id: noteID,
            mode: .plainText,
            updatedAt: memoryUpdatedAt.addingTimeInterval(-30)
        )
        let staleDocument = NoteDocument(metadata: staleMetadata, plainText: "stale file text")
        await store.save(staleDocument)

        await model.refreshFromDisk()

        #expect(model.note(for: noteID)?.plainText == "fresh in-memory text")
    }

    @Test func refreshFromDiskImportsStrictlyNewerExternalEdit() async {
        let store = InMemoryNoteStore()
        let model = makeModel(store: store)
        let noteID = await model.createNote()

        model.updatePlainText("local text", for: noteID)
        await pollUntilSaved(store: store, id: noteID, expected: "local text")

        guard let memoryUpdatedAt = model.note(for: noteID)?.metadata.updatedAt else {
            Issue.record("note missing after edit")
            return
        }
        let externalMetadata = NoteMetadata(
            id: noteID,
            mode: .plainText,
            updatedAt: memoryUpdatedAt.addingTimeInterval(30)
        )
        let externalDocument = NoteDocument(
            metadata: externalMetadata,
            plainText: "external device text"
        )
        await store.save(externalDocument)

        await model.refreshFromDisk()

        #expect(model.note(for: noteID)?.plainText == "external device text")
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
}
