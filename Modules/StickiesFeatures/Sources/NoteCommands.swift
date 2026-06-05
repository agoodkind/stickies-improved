//
//  NoteCommands.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
import StickiesApplication
import StickiesDesignSystem
import StickiesDomain
import SwiftUI

public struct NoteCommands: Commands {
    private static let colorSwatchSymbol = "circle.fill"
    private static let managerWindowID = "manager"

    // Size bounds for the Bigger/Smaller commands, matching a sane editing range; the
    // original defaults to the system font at size 12.
    private enum FontSize {
        static let step: Double = 1
        static let minimum: Double = 8
        static let maximum: Double = 96
    }

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @FocusedValue(\.focusedNoteID) private var focusedNoteID

    private let workspace: NoteWorkspaceModel
    private let updaterModel: UpdaterModel

    public init(workspace: NoteWorkspaceModel, updaterModel: UpdaterModel) {
        self.workspace = workspace
        self.updaterModel = updaterModel
    }

    public var body: some Commands {
        CommandMenu("Notes") {
            Button("New Note") {
                Task {
                    let noteID = await workspace.createNote()
                    openWindow(value: noteID)
                }
            }
            .keyboardShortcut("n")

            Button("Delete") {
                if let focusedNoteID {
                    dismissWindow(value: focusedNoteID)
                    workspace.trashNote(focusedNoteID)
                }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(focusedNoteID == nil)

            Divider()

            Button("Check for Updates") {
                updaterModel.checkForUpdates()
            }
        }

        // Add to the system Window menu so "Show All Notes" sits next to the
        // standard window list, opening the manager scene.
        CommandGroup(after: .windowList) {
            Button("Show All Notes") {
                openWindow(id: Self.managerWindowID)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }

        CommandMenu("Colour") {
            ForEach(NoteColor.allCases, id: \.self) { color in
                Button {
                    if let focusedNoteID {
                        workspace.updateColor(color, for: focusedNoteID)
                    }
                } label: {
                    Label {
                        Text(color.rawValue.capitalized)
                    } icon: {
                        Image(systemName: Self.colorSwatchSymbol)
                            .foregroundStyle(color.color)
                    }
                }
                .disabled(focusedNoteID == nil)
            }
        }

        CommandMenu("Format") {
            // The panels act on the first responder (the NSTextView), whose overridden
            // changeFont/changeColor persist the result through the workspace.
            Button("Show Fonts") {
                NSFontManager.shared.orderFrontFontPanel(nil)
            }
            .keyboardShortcut("t")
            .disabled(focusedNoteID == nil)

            Button("Show Colors") {
                NSColorPanel.shared.orderFront(nil)
            }
            .disabled(focusedNoteID == nil)

            Divider()

            Button("Bigger") {
                adjustFocusedFontSize(by: FontSize.step)
            }
            .keyboardShortcut("+")
            .disabled(focusedNoteID == nil)

            Button("Smaller") {
                adjustFocusedFontSize(by: -FontSize.step)
            }
            .keyboardShortcut("-")
            .disabled(focusedNoteID == nil)
        }
    }

    private func adjustFocusedFontSize(by delta: Double) {
        guard let focusedNoteID, let note = workspace.note(for: focusedNoteID) else { return }
        let currentSize = note.metadata.fontSize
        let proposedSize = currentSize + delta
        let clampedSize = min(max(proposedSize, FontSize.minimum), FontSize.maximum)
        guard clampedSize != currentSize else { return }
        workspace.updateFont(
            name: note.metadata.fontName,
            size: clampedSize,
            for: focusedNoteID
        )
    }
}
