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
  private func makeModel(
    store: InMemoryNoteStore,
    migrator: any LibraryMigrating = FakeLibraryMigrator()
  ) -> NoteWorkspaceModel {
    NoteWorkspaceModel(
      noteStore: store,
      libraryMonitor: NoopLibraryMonitor(),
      autosaveScheduler: ManualAutosaveScheduler(),
      libraryMigrator: migrator,
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

  @Test func updateFramePersistsThroughDebouncedAutosave() async {
    let store = InMemoryNoteStore()
    let model = makeModel(store: store)
    let noteID = await model.createNote()

    let frame = NoteFrame(x: 120, y: 240, width: 360, height: 480)
    model.updateFrame(frame, for: noteID)

    await pollUntilFrameSaved(store: store, id: noteID, expected: frame)

    #expect(model.noteFrame(for: noteID) == frame)
    let saved = await store.document(for: noteID)
    #expect(saved?.metadata.frame == frame)
  }

  @Test func setCollapsedPersistsFlagAndExpandedHeight() async {
    let store = InMemoryNoteStore()
    let model = makeModel(store: store)
    let noteID = await model.createNote()

    model.setCollapsed(true, expandedHeight: 420, for: noteID)

    await pollUntilCollapsedSaved(store: store, id: noteID, expected: true)

    #expect(model.isCollapsed(for: noteID) == true)
    #expect(model.expandedHeight(for: noteID) == 420)
    let saved = await store.document(for: noteID)
    #expect(saved?.metadata.collapsed == true)
    #expect(saved?.metadata.expandedHeight == 420)
  }

  @Test func setCollapsedFalseClearsFlagAndKeepsExpandedHeight() async {
    let store = InMemoryNoteStore()
    let model = makeModel(store: store)
    let noteID = await model.createNote()
    model.setCollapsed(true, expandedHeight: 420, for: noteID)
    await pollUntilCollapsedSaved(store: store, id: noteID, expected: true)

    model.setCollapsed(false, expandedHeight: 420, for: noteID)

    await pollUntilCollapsedSaved(store: store, id: noteID, expected: false)
    #expect(model.isCollapsed(for: noteID) == false)
    #expect(model.expandedHeight(for: noteID) == 420)
    let saved = await store.document(for: noteID)
    #expect(saved?.metadata.collapsed == false)
    #expect(saved?.metadata.expandedHeight == 420)
  }

  @Test func trashNoteMovesNoteToTrashAndPersistsFlag() async {
    let store = InMemoryNoteStore()
    let model = makeModel(store: store)
    let noteID = await model.createNote()

    model.trashNote(noteID)

    await pollUntilTrashedSaved(store: store, id: noteID, expected: true)

    #expect(model.note(for: noteID) == nil)
    #expect(model.activeNotes.contains { $0.id == noteID } == false)
    #expect(model.trashedNotes.contains { $0.id == noteID })
    let saved = await store.document(for: noteID)
    #expect(saved?.metadata.isTrashed == true)
  }

  @Test func restoreNoteReversesTrash() async {
    let store = InMemoryNoteStore()
    let model = makeModel(store: store)
    let noteID = await model.createNote()
    model.trashNote(noteID)
    await pollUntilTrashedSaved(store: store, id: noteID, expected: true)

    model.restoreNote(noteID)

    await pollUntilTrashedSaved(store: store, id: noteID, expected: false)
    #expect(model.note(for: noteID) != nil)
    #expect(model.activeNotes.contains { $0.id == noteID })
    #expect(model.trashedNotes.contains { $0.id == noteID } == false)
    let saved = await store.document(for: noteID)
    #expect(saved?.metadata.isTrashed == false)
  }

  @Test func deleteNotePermanentlyRemovesFromStoreAndMemory() async {
    let store = InMemoryNoteStore()
    let model = makeModel(store: store)
    let noteID = await model.createNote()
    model.trashNote(noteID)
    await pollUntilTrashedSaved(store: store, id: noteID, expected: true)

    await model.deleteNotePermanently(noteID)

    #expect(model.note(for: noteID) == nil)
    #expect(model.activeNotes.contains { $0.id == noteID } == false)
    #expect(model.trashedNotes.contains { $0.id == noteID } == false)
    let saved = await store.document(for: noteID)
    #expect(saved == nil)
  }

  @Test func createNoteAppliesRequestedColor() async {
    let store = InMemoryNoteStore()
    let model = makeModel(store: store)

    let noteID = await model.createNote(color: .pink)

    #expect(model.note(for: noteID)?.metadata.colorName == .pink)
  }

  @Test func switchStorageModeMigratesThenRefreshes() async {
    let store = InMemoryNoteStore()
    let migrator = FakeLibraryMigrator()
    let model = makeModel(store: store, migrator: migrator)
    let noteID = await model.createNote()

    await model.switchStorageMode(from: .local, to: .iCloud)

    let recorded = await migrator.recordedMigrations
    #expect(recorded == [FakeLibraryMigrator.Migration(from: .local, to: .iCloud)])
    // refreshFromDisk reloaded from the same store, so the note survives.
    #expect(model.note(for: noteID) != nil)
  }

  @Test func switchStorageModeToSameModeDoesNothing() async {
    let store = InMemoryNoteStore()
    let migrator = FakeLibraryMigrator()
    let model = makeModel(store: store, migrator: migrator)

    await model.switchStorageMode(from: .iCloud, to: .iCloud)

    let recorded = await migrator.recordedMigrations
    #expect(recorded.isEmpty)
  }

  private func pollUntilTrashedSaved(
    store: InMemoryNoteStore,
    id: NoteID,
    expected: Bool
  ) async {
    let maxAttempts = 200
    for _ in 0..<maxAttempts {
      let document = await store.document(for: id)
      if document?.metadata.isTrashed == expected {
        return
      }
      await Task.yield()
    }
  }

  private func pollUntilFrameSaved(
    store: InMemoryNoteStore,
    id: NoteID,
    expected: NoteFrame
  ) async {
    let maxAttempts = 200
    for _ in 0..<maxAttempts {
      let document = await store.document(for: id)
      if document?.metadata.frame == expected {
        return
      }
      await Task.yield()
    }
  }

  private func pollUntilCollapsedSaved(
    store: InMemoryNoteStore,
    id: NoteID,
    expected: Bool
  ) async {
    let maxAttempts = 200
    for _ in 0..<maxAttempts {
      let document = await store.document(for: id)
      if document?.metadata.collapsed == expected {
        return
      }
      await Task.yield()
    }
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
