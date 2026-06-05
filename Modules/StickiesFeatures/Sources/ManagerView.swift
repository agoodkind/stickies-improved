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
    }

    private static let updatedDateStyle = Date.FormatStyle.dateTime
        .year().month().day().hour().minute()

    @Environment(\.noteWorkspaceModel) private var workspace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var pendingPermanentDelete: NoteID?

    public init() {
        // Reads the workspace model from the environment.
    }

    public var body: some View {
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
        .navigationTitle("All Notes")
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

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .padding(.vertical, Layout.emptySectionVerticalPadding)
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
