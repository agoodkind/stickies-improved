//
//  ManagerView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDesignSystem
import StickiesDomain
import SwiftUI

/// The "All Notes" manager window. Lists every note in two sections, active notes
/// under "Notes" and soft-deleted notes under "Trash", each with row actions to
/// open, trash, restore, or permanently delete. This reproduces the function of the
/// original's hidden-note manager with a modern SwiftUI list rather than the legacy
/// AppKit table.
public struct ManagerView: View {
    private enum Layout {
        static let swatchSize: CGFloat = 14
        static let swatchCornerRadius: CGFloat = 3
        static let rowSpacing: CGFloat = 10
        static let emptySectionVerticalPadding: CGFloat = 6
        static let snippetLineLimit = 2
    }

    private static let updatedDateStyle = Date.FormatStyle.dateTime
        .year().month().day().hour().minute()

    @Environment(\.noteWorkspaceModel) private var workspace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var pendingPermanentDelete: NoteID?
    @State private var query = ""

    public init() {
        // Reads the workspace model from the environment.
    }

    public var body: some View {
        list
            .navigationTitle("All Notes")
            .searchable(text: $query, prompt: "Search notes")
            .confirmationDialog(
                "Delete this note permanently?",
                isPresented: permanentDeleteBinding,
                titleVisibility: .visible
            ) {
                Button("Delete Permanently", role: .destructive) {
                    confirmPermanentDelete()
                }
                Button("Cancel", role: .cancel) {
                    pendingPermanentDelete = nil
                }
            } message: {
                Text("This removes the note from disk and cannot be undone.")
            }
    }

    /// While searching, a single "Results" section replaces the two note
    /// sections; an empty query restores the normal sectioned list.
    @ViewBuilder private var list: some View {
        if isSearching {
            searchResultsList
        } else {
            sectionedList
        }
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchResults: [NoteSearchResult] {
        workspace?.searchResults(for: query) ?? []
    }

    @ViewBuilder private var searchResultsList: some View {
        List {
            Section("Results") {
                if searchResults.isEmpty {
                    emptyRow("No matches")
                } else {
                    ForEach(searchResults) { result in
                        resultRow(for: result)
                    }
                }
            }
        }
    }

    private var sectionedList: some View {
        List {
            Section("Notes") {
                if let workspace, !workspace.activeNotes.isEmpty {
                    ForEach(workspace.activeNotes) { note in
                        activeRow(for: note)
                    }
                } else {
                    emptyRow("No notes")
                }
            }

            Section("Trash") {
                if let workspace, !workspace.trashedNotes.isEmpty {
                    ForEach(workspace.trashedNotes) { note in
                        trashedRow(for: note)
                    }
                } else {
                    emptyRow("Trash is empty")
                }
            }
        }
    }

    @ViewBuilder private func activeRow(for note: NoteDocument) -> some View {
        rowContent(for: note)
            .contextMenu {
                Button("Open") { openWindow(value: note.id) }
                Button("Trash") { trash(note.id) }
            }
            .swipeActions(edge: .trailing) {
                Button("Trash", role: .destructive) { trash(note.id) }
            }
    }

    @ViewBuilder private func trashedRow(for note: NoteDocument) -> some View {
        rowContent(for: note)
            .contextMenu {
                Button("Restore") { workspace?.restoreNote(note.id) }
                Button("Delete Permanently", role: .destructive) {
                    pendingPermanentDelete = note.id
                }
            }
            .swipeActions(edge: .trailing) {
                Button("Delete", role: .destructive) {
                    pendingPermanentDelete = note.id
                }
                Button("Restore") { workspace?.restoreNote(note.id) }
                    .tint(.green)
            }
    }

    private func rowContent(for note: NoteDocument) -> some View {
        HStack(spacing: Layout.rowSpacing) {
            RoundedRectangle(cornerRadius: Layout.swatchCornerRadius)
                .fill(note.metadata.colorName.color)
                .frame(width: Layout.swatchSize, height: Layout.swatchSize)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.swatchCornerRadius)
                        .stroke(.separator)
                )
            VStack(alignment: .leading) {
                Text(note.metadata.title)
                    .lineLimit(1)
                Text(note.metadata.updatedAt, format: Self.updatedDateStyle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// A single search-result row: color swatch, title, the context snippet, and
    /// a "Trash" badge when the hit lives in the trash. Active results open the
    /// note window; trashed results offer Restore, which moves the note back into
    /// the active set and then opens it.
    @ViewBuilder private func resultRow(for result: NoteSearchResult) -> some View {
        HStack(spacing: Layout.rowSpacing) {
            RoundedRectangle(cornerRadius: Layout.swatchCornerRadius)
                .fill(result.color.color)
                .frame(width: Layout.swatchSize, height: Layout.swatchSize)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.swatchCornerRadius)
                        .stroke(.separator)
                )
            VStack(alignment: .leading) {
                HStack {
                    Text(result.title)
                        .lineLimit(1)
                    if result.isTrashed {
                        Text("Trash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Layout.emptySectionVerticalPadding)
                            .overlay(
                                Capsule().stroke(.separator)
                            )
                    }
                }
                Text(result.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(Layout.snippetLineLimit)
            }
            Spacer()
            if result.isTrashed {
                Button("Restore") { restoreAndOpen(result.noteID) }
            } else {
                Button("Open") { openWindow(value: result.noteID) }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !result.isTrashed {
                openWindow(value: result.noteID)
            }
        }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .padding(.vertical, Layout.emptySectionVerticalPadding)
    }

    private func restoreAndOpen(_ noteID: NoteID) {
        // Restore moves the note back into the active set, then the window opens
        // it; opening only works for active notes, so the order matters.
        workspace?.restoreNote(noteID)
        openWindow(value: noteID)
    }

    private func trash(_ noteID: NoteID) {
        // Close the note's window if it is open so the soft delete also dismisses
        // the editor, then flip the model state so it leaves the active set.
        dismissWindow(value: noteID)
        workspace?.trashNote(noteID)
    }

    private func confirmPermanentDelete() {
        guard let noteID = pendingPermanentDelete else { return }
        pendingPermanentDelete = nil
        Task { await workspace?.deleteNotePermanently(noteID) }
    }

    private var permanentDeleteBinding: Binding<Bool> {
        Binding(
            get: { pendingPermanentDelete != nil },
            set: { isPresented in
                if !isPresented {
                    pendingPermanentDelete = nil
                }
            }
        )
    }
}
