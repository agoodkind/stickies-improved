//
//  NoteEditorHost.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

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
            MarkdownEditorView()
        }
    }
}
