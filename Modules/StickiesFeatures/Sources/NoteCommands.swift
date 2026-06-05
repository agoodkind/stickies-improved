//
//  NoteCommands.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDesignSystem
import StickiesDomain
import SwiftUI

public struct NoteCommands: Commands {
    private static let colorSwatchSymbol = "circle.fill"

    @Environment(\.openWindow) private var openWindow
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

            Divider()

            Button("Check for Updates") {
                updaterModel.checkForUpdates()
            }
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
    }
}
