//
//  NoteCommands.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import SwiftUI

public struct NoteCommands: Commands {
    @Environment(\.openWindow) private var openWindow

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
    }
}
