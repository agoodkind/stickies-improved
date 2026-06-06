//
//  NotePreviewView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesDesignSystem
import StickiesDomain
import SwiftUI

/// The manager's detail pane: a read-only preview of the selected note. It mirrors the
/// real note window by drawing the full text on a colored "paper" card with the note's
/// own font size and adaptive background, and offers the primary actions for the note
/// through injected closures so it stays decoupled from the workspace model.
struct NotePreviewView: View {
    private enum Layout {
        static let headerSpacing: CGFloat = 12
        static let panePadding: CGFloat = 16
        static let paperPadding: CGFloat = 18
        static let paperCornerRadius: CGFloat = 10
        static let paperShadowRadius: CGFloat = 6
        static let paperShadowY: CGFloat = 2
        static let paperShadowOpacity: CGFloat = 0.18
        static let actionSpacing: CGFloat = 12
        static let swatchSize: CGFloat = 16
        static let swatchCornerRadius: CGFloat = 4
    }

    private static let editedDateStyle = Date.FormatStyle.dateTime
        .year().month().day().hour().minute()

    @Environment(\.colorScheme) private var colorScheme

    let note: NoteDocument
    let onOpen: () -> Void
    let onRestore: () -> Void
    let onTrash: () -> Void
    let onDeletePermanently: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            paper
            Divider()
            actions
        }
    }

    private var isTrashed: Bool {
        note.metadata.isTrashed
    }

    private var header: some View {
        HStack(spacing: Layout.headerSpacing) {
            NoteColorSwatch(
                note.metadata.colorName,
                size: Layout.swatchSize,
                cornerRadius: Layout.swatchCornerRadius
            )
            VStack(alignment: .leading) {
                HStack {
                    Text(note.metadata.title)
                        .font(.headline)
                        .lineLimit(1)
                    if isTrashed {
                        TrashBadge()
                    }
                }
                Text("Edited \(note.metadata.updatedAt.formatted(Self.editedDateStyle))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(Layout.panePadding)
    }

    private var paper: some View {
        paperBody
            .background(note.metadata.colorName.backgroundColor(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Layout.paperCornerRadius))
            .shadow(
                color: .black.opacity(Layout.paperShadowOpacity),
                radius: Layout.paperShadowRadius,
                y: Layout.paperShadowY
            )
            .padding(Layout.panePadding)
    }

    /// Renders the full note body with the same `NSTextView`-backed editor the note window
    /// uses, in read-only mode. TextKit 2 lays out only the visible viewport, so even a very
    /// large note shows its full text without blocking the main thread when selected, and the
    /// preview stays DRY with the real editor instead of a separate SwiftUI `Text`.
    @ViewBuilder private var paperBody: some View {
        if note.plainText.isEmpty {
            Text("This note is empty.")
                .italic()
                .foregroundStyle(.secondary)
                .font(.system(size: note.metadata.fontSize))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Layout.paperPadding)
        } else {
            // No extra padding: the editor carries its own text-container insets, the same as
            // the note window, so the preview's margins match the real note instead of being
            // doubled up by an outer pad.
            StickyTextEditor(
                text: .constant(note.plainText),
                fontName: note.metadata.fontName,
                fontSize: note.metadata.fontSize,
                fontColorHex: note.metadata.fontColorHex,
                isEditable: false
            )
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: Layout.actionSpacing) {
            if isTrashed {
                Button(action: onRestore) {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
                Button(role: .destructive, action: onDeletePermanently) {
                    Label("Delete Permanently", systemImage: "trash")
                }
            } else {
                Button(action: onOpen) {
                    Label("Open", systemImage: "macwindow")
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
                Button(role: .destructive, action: onTrash) {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
        }
        .padding(Layout.panePadding)
    }
}

// MARK: - TrashBadge

/// A small outlined "Trash" pill that marks a note living in the trash, shared by the
/// manager's search rows and the preview header.
struct TrashBadge: View {
    private enum Layout {
        static let horizontalPadding: CGFloat = 6
    }

    var body: some View {
        Text("Trash")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Layout.horizontalPadding)
            .overlay(
                Capsule().stroke(.separator)
            )
    }
}
