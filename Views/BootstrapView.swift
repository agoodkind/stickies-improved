import AppKit
import PlainStickiesCore
import SwiftUI

struct BootstrapView: View {
    @Environment(NoteWorkspaceStore.self) private var workspace
    @Environment(NoteWindowStateStore.self) private var windowStateStore
    @Environment(\.openWindow) private var openWindow

    @State private var didOpenWindows = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(RuntimeEnvironment.isRunningTests ? "Running tests…" : "Loading notes…")
                .font(.headline)

            Text(RuntimeEnvironment.isRunningTests ? "The host app is idle while XCTest runs." : "PlainStickies restores your note windows and keeps note content in your iCloud document library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let error = workspace.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Create New Note") {
                Task {
                    let noteID = await workspace.createNote()
                    openWindow(value: noteID)
                    closeBootstrapWindow()
                }
            }
        }
        .padding(20)
        .task {
            guard !RuntimeEnvironment.isRunningTests else { return }
            guard !didOpenWindows else { return }
            didOpenWindows = true

            let noteIDs = await workspace.bootstrap(openNoteIDs: windowStateStore.openNoteIDs)
            for noteID in noteIDs {
                openWindow(value: noteID)
            }

            if !noteIDs.isEmpty {
                try? await Task.sleep(for: .milliseconds(250))
                closeBootstrapWindow()
            }
        }
    }

    private func closeBootstrapWindow() {
        NSApp.keyWindow?.close()
    }
}
