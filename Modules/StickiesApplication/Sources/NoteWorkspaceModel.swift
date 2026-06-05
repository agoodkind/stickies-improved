//
//  NoteWorkspaceModel.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Observation
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

    public private(set) var notes: [NoteID: NoteDocument] = [:]
    public private(set) var orderedNoteIDs: [NoteID] = []
    public private(set) var storageLocationDescription = "Loading..."
    public private(set) var lastErrorMessage: String?
    public private(set) var didFinishBootstrap = false

    private var autosaveTasks: [NoteID: Task<Void, Never>] = [:]

    public init(
        noteStore: any NoteStore,
        libraryMonitor: any LibraryMonitoring,
        autosaveScheduler: any AutosaveScheduling,
        loggerSubsystem: String
    ) {
        self.noteStore = noteStore
        self.libraryMonitor = libraryMonitor
        self.autosaveScheduler = autosaveScheduler
        logger = Logger(subsystem: loggerSubsystem, category: "NoteWorkspaceModel")
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
            notes = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            orderedNoteIDs =
                loaded
                .sorted { $0.metadata.updatedAt > $1.metadata.updatedAt }
                .map(\.id)
        } catch {
            logger.error(
                "Refresh from disk failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = error.localizedDescription
        }
    }

    public func createNote() async -> NoteID {
        let note = NoteDocument()
        await upsert(note)
        return note.id
    }

    public func note(for noteID: NoteID) -> NoteDocument? {
        notes[noteID]
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
        guard var document = notes[noteID] else { return }
        document.updatePlainText(plainText)
        notes[noteID] = document
        reorderNotes()
        scheduleAutosave(for: document)
    }

    public func updateColor(_ color: NoteColor, for noteID: NoteID) {
        guard var document = notes[noteID] else { return }
        document.metadata.colorName = color
        document.metadata.updatedAt = .now
        notes[noteID] = document
        reorderNotes()
        // Persist immediately rather than through the debounce: a color pick is a
        // discrete, deliberate change with no rapid follow-up to coalesce.
        Task { await persistImmediately(document) }
    }

    public func updateFont(name: String?, size: Double, for noteID: NoteID) {
        guard var document = notes[noteID] else { return }
        document.metadata.fontName = name
        document.metadata.fontSize = size
        document.metadata.updatedAt = .now
        notes[noteID] = document
        reorderNotes()
        // A font pick is a discrete change with no rapid follow-up to coalesce, so
        // persist straight away rather than through the typing debounce.
        Task { await persistImmediately(document) }
    }

    public func updateFontColor(hex: String?, for noteID: NoteID) {
        guard var document = notes[noteID] else { return }
        document.metadata.fontColorHex = hex
        document.metadata.updatedAt = .now
        notes[noteID] = document
        reorderNotes()
        Task { await persistImmediately(document) }
    }

    /// Records a new window frame for the note. A drag or live resize fires this
    /// rapidly, so the write goes through the debounced autosave scheduler rather
    /// than hitting disk on every event. The window frame is not user-visible
    /// content, so it does not touch `updatedAt` and does not reorder the list.
    public func updateFrame(_ frame: NoteFrame, for noteID: NoteID) {
        guard var document = notes[noteID] else { return }
        document.metadata.frame = frame
        notes[noteID] = document
        scheduleAutosave(for: document)
    }

    /// Persists the fold state and the height to restore on expand. A fold is a
    /// discrete toggle with no rapid follow-up, so it saves immediately.
    public func setCollapsed(
        _ collapsed: Bool,
        expandedHeight: Double?,
        for noteID: NoteID
    ) {
        guard var document = notes[noteID] else { return }
        document.metadata.collapsed = collapsed
        document.metadata.expandedHeight = expandedHeight
        notes[noteID] = document
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
        guard var conflictCopy = notes[noteID] else { return }
        conflictCopy.metadata.id = NoteID()
        conflictCopy.metadata.title = "\(conflictCopy.metadata.title) Conflict Copy"
        conflictCopy.metadata.updatedAt = .now
        conflictCopy.metadata.createdAt = .now
        await upsert(conflictCopy)
    }

    private func ensureSeedNoteIfNeeded() async throws {
        if try await noteStore.loadAllDocuments().isEmpty {
            let note = NoteDocument()
            try await noteStore.save(note)
        }
    }

    private func upsert(_ document: NoteDocument) async {
        notes[document.id] = document
        reorderNotes()
        do {
            try await noteStore.save(document)
        } catch {
            logger.error("Upsert save failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = error.localizedDescription
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
        orderedNoteIDs = notes.values
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
