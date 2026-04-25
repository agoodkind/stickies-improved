import PlainStickiesCore
import SwiftUI

struct NoteCommands: Commands {
    @Environment(NoteWorkspaceStore.self) private var workspace
    @Environment(AppUpdater.self) private var appUpdater
    @Environment(\.openWindow) private var openWindow

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
