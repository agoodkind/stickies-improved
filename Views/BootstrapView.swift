import AppKit
import StickiesImprovedCore
import SwiftUI

struct BootstrapView: View {
    @Environment(NoteWorkspaceStore.self) private var workspace
    @Environment(NoteWindowStateStore.self) private var windowStateStore
    @Environment(\.openWindow) private var openWindow

    @State private var didOpenWindows = false

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .task {
                guard !RuntimeEnvironment.isRunningTests else { return }
                guard !didOpenWindows else { return }
                didOpenWindows = true

                let noteIDs = await workspace.bootstrap(openNoteIDs: windowStateStore.openNoteIDs)
                for noteID in noteIDs {
                    openWindow(value: noteID)
                }

                if !noteIDs.isEmpty {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }
}
