//
//  NoteWorkspaceStore.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Observation
import SwiftUI
import os

@preconcurrency
@Observable
@MainActor
public final class NoteWorkspaceStore {
    private static let autosaveDelayMilliseconds = 450

    private let logger = Logger(subsystem: BuildConfig.appBundleID, category: "NoteWorkspaceStore")
    private let packageStore: NotePackageStore
    private let metadataMonitor: UbiquityMetadataMonitor

    public private(set) var notes: [NoteID: NoteDocument] = [:]
    public private(set) var orderedNoteIDs: [NoteID] = []
    public private(set) var storageLocationDescription = "Loading..."
    public private(set) var lastErrorMessage: String?
    public private(set) var didFinishBootstrap = false

    private var autosaveTasks: [NoteID: Task<Void, Never>] = [:]

    public init(
        packageStore: NotePackageStore = NotePackageStore(),
        metadataMonitor: UbiquityMetadataMonitor = UbiquityMetadataMonitor()
    ) {
        self.packageStore = packageStore
        self.metadataMonitor = metadataMonitor

        self.metadataMonitor.onLibraryDidChange = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refreshFromDisk()
            }
        }
    }

    public func bootstrap(openNoteIDs preferredIDs: [NoteID]) async -> [NoteID] {
        do {
            let resolvedRoot = try await packageStore.ensureLibraryDirectory()
            storageLocationDescription = resolvedRoot.path
            metadataMonitor.startMonitoring(rootURL: resolvedRoot)

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
            let loaded = try await packageStore.loadAllDocuments()
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
        if try await packageStore.loadAllDocuments().isEmpty {
            let note = NoteDocument()
            try await packageStore.save(note)
        }
    }

    private func upsert(_ document: NoteDocument) async {
        notes[document.id] = document
        reorderNotes()
        do {
            try await packageStore.save(document)
        } catch {
            logger.error("Upsert save failed: \(error.localizedDescription, privacy: .public)")
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
        autosaveTasks[document.id] = Task { [weak self] in
            let delay = Duration.milliseconds(Self.autosaveDelayMilliseconds)
            do {
                try await ContinuousClock().sleep(for: delay)
            } catch {
                return  // debounce cancelled before the delay elapsed
            }
            guard !Task.isCancelled else { return }

            do {
                try await self?.packageStore.save(document)
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
