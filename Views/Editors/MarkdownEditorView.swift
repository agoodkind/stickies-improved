import PlainStickiesCore
import SwiftUI

struct MarkdownEditorView: View {
    let noteID: NoteID

    var body: some View {
        ContentUnavailableView(
            "Markdown Is Not Enabled",
            systemImage: "text.document",
            description: Text("The storage and windowing model already reserves a markdown mode, but the editor is intentionally deferred.")
        )
    }
}
