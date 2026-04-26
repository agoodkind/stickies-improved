import StickiesImprovedCore
import SwiftUI

struct NoteEditorHost: View {
    @Environment(NoteWorkspaceStore.self) private var workspace

    let noteID: NoteID

    var body: some View {
        switch workspace.note(for: noteID)?.metadata.mode ?? .plainText {
        case .plainText:
            PlainTextEditorView(noteID: noteID)
        case .markdown:
            MarkdownEditorView(noteID: noteID)
        }
    }
}
