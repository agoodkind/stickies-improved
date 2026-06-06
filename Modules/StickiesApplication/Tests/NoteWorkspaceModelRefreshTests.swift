//
//  NoteWorkspaceModelRefreshTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 06/06/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesCRDT
import StickiesDomain
import StickiesTestSupport
import Testing

@testable import StickiesApplication

/// Covers `refreshFromDisk`'s CRDT merge. Our own autosave surfaces back through the library
/// monitor as a reload, so reloading our own write must not lose in-flight text, and a
/// genuinely concurrent edit from another device must merge in rather than overwrite.
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

    @Test func reloadingOwnWriteKeepsText() async {
        // The autosave write reloaded through the monitor must be idempotent: merging the
        // note's own serialized history back into itself changes nothing.
        let store = InMemoryNoteStore()
        let model = makeModel(store: store)
        let noteID = await model.createNote()
        model.updatePlainText("stable text", for: noteID)
        await pollUntilSaved(store: store, id: noteID, expected: "stable text")

        await model.refreshFromDisk()

        #expect(model.note(for: noteID)?.plainText == "stable text")
    }

    @Test func concurrentExternalEditMergesInsteadOfOverwriting() async {
        // Another device edits the same note from a shared base; both edits must survive the
        // reload instead of one clobbering the other.
        let store = InMemoryNoteStore()
        let model = makeModel(store: store)
        let noteID = await model.createNote()
        model.updatePlainText("Hello", for: noteID)
        await pollUntilSaved(store: store, id: noteID, expected: "Hello")

        // Fork the persisted document on a simulated second device and edit it there.
        guard let baseData = await store.document(for: noteID)?.crdtData,
            let remote = try? NoteCRDT.load(from: baseData)
        else {
            Issue.record("missing persisted crdt data")
            return
        }
        remote.setBodyText("Hello remote")
        guard var remoteDocument = await store.document(for: noteID) else {
            Issue.record("missing stored document")
            return
        }
        remoteDocument.crdtData = remote.serialized()
        await store.save(remoteDocument)

        // Meanwhile edit locally, then reload: the merge keeps both insertions.
        model.updatePlainText("Hello local", for: noteID)
        await model.refreshFromDisk()

        let merged = model.note(for: noteID)?.plainText ?? ""
        #expect(merged.contains("Hello"))
        #expect(merged.contains("local"))
        #expect(merged.contains("remote"))
    }

    @Test func legacyNoteWithoutCRDTIsSeededAndPersisted() async {
        // A package that predates the CRDT (no crdtData) loads, gets a seeded Automerge
        // document, and that document is written back so it becomes merge-aware.
        let store = InMemoryNoteStore()
        let legacyID = NoteID()
        let legacy = NoteDocument(
            metadata: NoteMetadata(id: legacyID, mode: .plainText),
            plainText: "legacy body"
        )
        await store.save(legacy)
        let model = makeModel(store: store)

        await model.refreshFromDisk()

        #expect(model.note(for: legacyID)?.plainText == "legacy body")
        await pollUntilCRDTPersisted(store: store, id: legacyID)
        let saved = await store.document(for: legacyID)
        #expect(saved?.crdtData != nil)
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

    private func pollUntilCRDTPersisted(store: InMemoryNoteStore, id: NoteID) async {
        let maxAttempts = 200
        for _ in 0..<maxAttempts {
            if await store.document(for: id)?.crdtData != nil {
                return
            }
            await Task.yield()
        }
    }
}
