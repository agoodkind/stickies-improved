//
//  NoteWorkspaceModel.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Observation
import StickiesCRDT
import StickiesDomain
import SwiftUI
import os

@preconcurrency
@MainActor
@Observable
public final class NoteWorkspaceModel {
    private static let autosaveDelayMilliseconds = 450

    private let logger: Logger
    private let noteStore: any NoteStore
    private let libraryMonitor: any LibraryMonitoring
    private let autosaveScheduler: any AutosaveScheduling
    private let libraryMigrator: any LibraryMigrating

    // `notes` and `orderedNoteIDs` hold only the ACTIVE (non-trashed) notes, so the
    // existing window, ordering, and bootstrap paths never see a trashed note.
    // Trashed notes live in a parallel store the manager window reads from.
    public private(set) var notes: [NoteID: NoteDocument] = [:]
    public private(set) var orderedNoteIDs: [NoteID] = []
    public private(set) var trashedNotesByID: [NoteID: NoteDocument] = [:]
    public private(set) var orderedTrashedNoteIDs: [NoteID] = []
    public private(set) var storageLocationDescription = "Loading..."
    public private(set) var lastErrorMessage: String?
    public private(set) var didFinishBootstrap = false

    private var autosaveTasks: [NoteID: Task<Void, Never>] = [:]

    // The merge-aware source of truth for every note, active or trashed, keyed by id. The
    // `notes`/`trashedNotesByID` documents are the materialized view derived from these; all
    // edits mutate the CRDT and then re-materialize. A note is in exactly one of the two
    // collections at a time, so a single id-keyed map serves both.
    private var crdts: [NoteID: NoteCRDT] = [:]

    public init(
        noteStore: any NoteStore,
        libraryMonitor: any LibraryMonitoring,
        autosaveScheduler: any AutosaveScheduling,
        libraryMigrator: any LibraryMigrating,
        loggerSubsystem: String
    ) {
        self.noteStore = noteStore
        self.libraryMonitor = libraryMonitor
        self.autosaveScheduler = autosaveScheduler
        self.libraryMigrator = libraryMigrator
        logger = Logger(subsystem: loggerSubsystem, category: "NoteWorkspaceModel")
    }

    /// Moves the library between roots when the storage mode changes, then reloads
    /// from disk so the active collections reflect the new root. The caller must
    /// persist the new mode first so `refreshFromDisk` resolves the destination.
    public func switchStorageMode(
        from oldMode: StorageMode,
        to newMode: StorageMode
    ) async {
        guard oldMode != newMode else {
            return
        }
        do {
            try await libraryMigrator.migrate(from: oldMode, to: newMode)
        } catch {
            logger.error(
                "Storage mode migration failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = error.localizedDescription
        }
        await refreshFromDisk()
    }

    public func bootstrap(openNoteIDs preferredIDs: [NoteID]) async -> [NoteID] {
        do {
            let resolvedRoot = try await noteStore.ensureLibraryDirectory()
            storageLocationDescription = resolvedRoot.path
            libraryMonitor.startMonitoring(rootURL: resolvedRoot) { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.refreshFromDisk()
                }
            }

            try await ensureSeedNoteIfNeeded()
            await refreshFromDisk()
        } catch {
            logger.error("Bootstrap failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = error.localizedDescription
        }

        didFinishBootstrap = true
        let candidates = preferredIDs.filter { notes[$0] != nil }
        if !candidates.isEmpty {
            return candidates
        }
        return orderedNoteIDs.first.map { [$0] } ?? []
    }

    public func refreshFromDisk() async {
        do {
            let loaded = try await noteStore.loadAllDocuments()
            let loadedIDs = Set(loaded.map(\.id))

            // Drop notes whose packages disappeared (deleted on another device).
            for id in Set(crdts.keys).subtracting(loadedIDs) {
                crdts[id] = nil
                notes[id] = nil
                trashedNotesByID[id] = nil
            }

            for document in loaded {
                await reconcile(loaded: document)
            }

            reorderNotes()
            reorderTrashedNotes()
        } catch {
            logger.error(
                "Refresh from disk failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Folds one freshly loaded package into memory. When a live CRDT already exists for the
    /// note, the loaded document is merged into it: our own debounced autosave reloads here
    /// too, and merging the same history is idempotent, so in-flight keystrokes are never
    /// clobbered, while a genuinely concurrent edit from another device merges
    /// character-by-character instead of overwriting. A package without an Automerge
    /// document is a legacy note, seeded into a CRDT and persisted so it becomes merge-aware.
    private func reconcile(loaded document: NoteDocument) async {
        let id = document.id
        if let existing = crdts[id] {
            if let data = document.crdtData, let incoming = try? NoteCRDT.load(from: data) {
                try? existing.merge(incoming)
            }
            materialize(existing, id: id)
        } else if let data = document.crdtData, let crdt = try? NoteCRDT.load(from: data) {
            crdts[id] = crdt
            materialize(crdt, id: id)
        } else {
            let crdt = NoteCRDT.seeded(from: document)
            crdts[id] = crdt
            let materialized = materialize(crdt, id: id)
            await persistImmediately(materialized)
        }
    }

    /// Rebuilds the materialized document for `id` from its CRDT and files it into the active
    /// or trashed collection by its trashed flag. The stored document carries the serialized
    /// bytes, so a subsequent save writes `note.automerge` alongside the readable mirror.
    @discardableResult
    private func materialize(_ crdt: NoteCRDT, id: NoteID) -> NoteDocument {
        var document = crdt.materialized(fallbackID: id)
        document.crdtData = crdt.serialized()
        if document.metadata.isTrashed {
            notes[id] = nil
            trashedNotesByID[id] = document
        } else {
            trashedNotesByID[id] = nil
            notes[id] = document
        }
        return document
    }

    /// Active notes in display order (newest first), for the manager's Notes section.
    public var activeNotes: [NoteDocument] {
        orderedNoteIDs.compactMap { notes[$0] }
    }

    /// Trashed notes in display order (newest first), for the manager's Trash section.
    public var trashedNotes: [NoteDocument] {
        orderedTrashedNoteIDs.compactMap { trashedNotesByID[$0] }
    }

    /// Soft delete: flags the note trashed and persists it, then moves it out of the
    /// active collections so its window no longer counts as open and it drops from
    /// the normal note set while staying on disk for the manager to list.
    public func trashNote(_ noteID: NoteID) {
        guard let crdt = crdts[noteID] else { return }
        crdt.setTrashed(true, updatedAt: .now)
        let document = materialize(crdt, id: noteID)
        reorderNotes()
        reorderTrashedNotes()
        Task { await persistImmediately(document) }
    }

    /// Reverses a soft delete: clears the trashed flag, persists, and moves the note
    /// back into the active collections so it appears in the normal note set again.
    public func restoreNote(_ noteID: NoteID) {
        guard let crdt = crdts[noteID] else { return }
        crdt.setTrashed(false, updatedAt: .now)
        let document = materialize(crdt, id: noteID)
        reorderTrashedNotes()
        reorderNotes()
        Task { await persistImmediately(document) }
    }

    /// Permanently removes the note's package from disk and drops it from every
    /// in-memory collection. There is no undo, so the manager confirms first.
    public func deleteNotePermanently(_ noteID: NoteID) async {
        do {
            try await noteStore.delete(id: noteID)
        } catch {
            logger.error(
                "Permanent delete failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = error.localizedDescription
            return
        }
        autosaveTasks[noteID]?.cancel()
        autosaveTasks[noteID] = nil
        crdts[noteID] = nil
        notes[noteID] = nil
        trashedNotesByID[noteID] = nil
        reorderNotes()
        reorderTrashedNotes()
    }

    public func createNote(color: NoteColor = .default) async -> NoteID {
        var note = NoteDocument()
        note.metadata.colorName = color
        let crdt = NoteCRDT.seeded(from: note)
        crdts[note.id] = crdt
        let document = materialize(crdt, id: note.id)
        reorderNotes()
        await persistImmediately(document)
        return note.id
    }

    public func note(for noteID: NoteID) -> NoteDocument? {
        notes[noteID]
    }

    /// Looks a note up across both the active and trashed collections. The manager's
    /// preview pane is driven by a selected id that can land on either kind, so it
    /// needs a lookup that does not assume the note is still active.
    public func anyDocument(for noteID: NoteID) -> NoteDocument? {
        notes[noteID] ?? trashedNotesByID[noteID]
    }

    public func binding(for noteID: NoteID) -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.notes[noteID]?.plainText ?? ""
            },
            set: { [weak self] newValue in
                self?.updatePlainText(newValue, for: noteID)
            }
        )
    }

    public func updatePlainText(_ plainText: String, for noteID: NoteID) {
        guard let crdt = crdts[noteID] else { return }
        crdt.setBodyText(plainText)
        crdt.setUpdatedAt(.now)
        let document = materialize(crdt, id: noteID)
        reorderNotes()
        scheduleAutosave(for: document)
    }

    public func updateColor(_ color: NoteColor, for noteID: NoteID) {
        guard let crdt = crdts[noteID] else { return }
        crdt.setColor(color, updatedAt: .now)
        let document = materialize(crdt, id: noteID)
        reorderNotes()
        // Persist immediately rather than through the debounce: a color pick is a
        // discrete, deliberate change with no rapid follow-up to coalesce.
        Task { await persistImmediately(document) }
    }

    public func updateFont(name: String?, size: Double, for noteID: NoteID) {
        guard let crdt = crdts[noteID] else { return }
        crdt.setFont(name: name, size: size, updatedAt: .now)
        let document = materialize(crdt, id: noteID)
        reorderNotes()
        // A font pick is a discrete change with no rapid follow-up to coalesce, so
        // persist straight away rather than through the typing debounce.
        Task { await persistImmediately(document) }
    }

    public func updateFontColor(hex: String?, for noteID: NoteID) {
        guard let crdt = crdts[noteID] else { return }
        crdt.setFontColor(hex: hex, updatedAt: .now)
        let document = materialize(crdt, id: noteID)
        reorderNotes()
        Task { await persistImmediately(document) }
    }

    /// Records a new window frame for the note. A drag or live resize fires this
    /// rapidly, so the write goes through the debounced autosave scheduler rather
    /// than hitting disk on every event. The window frame is not user-visible
    /// content, so it does not touch `updatedAt` and does not reorder the list.
    public func updateFrame(_ frame: NoteFrame, for noteID: NoteID) {
        guard let crdt = crdts[noteID] else { return }
        crdt.setFrame(frame)
        let document = materialize(crdt, id: noteID)
        scheduleAutosave(for: document)
    }

    /// Persists the fold state and the height to restore on expand. A fold is a
    /// discrete toggle with no rapid follow-up, so it saves immediately.
    public func setCollapsed(
        _ collapsed: Bool,
        expandedHeight: Double?,
        for noteID: NoteID
    ) {
        guard let crdt = crdts[noteID] else { return }
        crdt.setCollapsed(collapsed, expandedHeight: expandedHeight)
        let document = materialize(crdt, id: noteID)
        Task { await persistImmediately(document) }
    }

    public func noteFrame(for noteID: NoteID) -> NoteFrame? {
        notes[noteID]?.metadata.frame
    }

    public func isCollapsed(for noteID: NoteID) -> Bool {
        notes[noteID]?.metadata.collapsed ?? NoteMetadata.Default.collapsed
    }

    public func expandedHeight(for noteID: NoteID) -> Double? {
        notes[noteID]?.metadata.expandedHeight
    }

    public func displayTitle(for noteID: NoteID) -> String {
        notes[noteID]?.metadata.title ?? "Untitled"
    }

    public func duplicateConflictCopy(for noteID: NoteID) async {
        guard let original = notes[noteID] else { return }
        var conflictCopy = original
        conflictCopy.metadata.id = NoteID()
        conflictCopy.metadata.title = "\(conflictCopy.metadata.title) Conflict Copy"
        conflictCopy.metadata.updatedAt = .now
        conflictCopy.metadata.createdAt = .now
        conflictCopy.crdtData = nil
        let crdt = NoteCRDT.seeded(from: conflictCopy)
        crdts[conflictCopy.id] = crdt
        let document = materialize(crdt, id: conflictCopy.id)
        reorderNotes()
        await persistImmediately(document)
    }

    private func ensureSeedNoteIfNeeded() async throws {
        if try await noteStore.loadAllDocuments().isEmpty {
            let note = NoteDocument()
            let crdt = NoteCRDT.seeded(from: note)
            var document = crdt.materialized(fallbackID: note.id)
            document.crdtData = crdt.serialized()
            try await noteStore.save(document)
        }
    }

    private func persistImmediately(_ document: NoteDocument) async {
        do {
            try await noteStore.save(document)
        } catch {
            logger.error(
                "Immediate save failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = error.localizedDescription
        }
    }

    private func reorderNotes() {
        orderedNoteIDs = Self.orderedByUpdatedDescending(Array(notes.values))
    }

    private func reorderTrashedNotes() {
        orderedTrashedNoteIDs = Self.orderedByUpdatedDescending(Array(trashedNotesByID.values))
    }

    private static func orderedByUpdatedDescending(
        _ documents: [NoteDocument]
    ) -> [NoteID] {
        documents
            .sorted { $0.metadata.updatedAt > $1.metadata.updatedAt }
            .map(\.id)
    }

    private func scheduleAutosave(for document: NoteDocument) {
        autosaveTasks[document.id]?.cancel()
        let scheduler = autosaveScheduler
        let store = noteStore
        autosaveTasks[document.id] = Task { [weak self] in
            let delay = Duration.milliseconds(Self.autosaveDelayMilliseconds)
            do {
                try await scheduler.sleep(for: delay)
            } catch {
                return  // debounce cancelled before the delay elapsed
            }
            guard !Task.isCancelled else { return }

            do {
                try await store.save(document)
            } catch {
                await MainActor.run {
                    self?.logger.error(
                        "Autosave failed: \(error.localizedDescription, privacy: .public)"
                    )
                    self?.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }
}
