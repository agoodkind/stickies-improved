import PlainStickiesCore
import SwiftUI

struct NoteSceneView: View {
    @Environment(NoteWorkspaceStore.self) private var workspace
    @Environment(NoteWindowStateStore.self) private var windowStateStore

    @Binding var noteID: NoteID?

    var body: some View {
        Group {
            if let noteID {
                NoteEditorHost(noteID: noteID)
            } else {
                ContentUnavailableView("No Note", systemImage: "note.text")
            }
        }
        .frame(minWidth: 240, idealWidth: 280, minHeight: 180, idealHeight: 240)
        .navigationTitle(noteID.map(workspace.displayTitle(for:)) ?? "Note")
        .containerBackground(.clear, for: .window)
        .onAppear {
            if let noteID {
                windowStateStore.noteWindowOpened(noteID)
            }
        }
        .onDisappear {
            if let noteID {
                windowStateStore.noteWindowClosed(noteID)
            }
        }
    }
}
