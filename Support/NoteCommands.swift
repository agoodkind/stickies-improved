import StickiesImprovedCore
import SwiftUI

struct NoteCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    let workspace: NoteWorkspaceStore
    let appUpdater: AppUpdater

    var body: some Commands {
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
                appUpdater.checkForUpdates()
            }
        }
    }
}
