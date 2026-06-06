//
//  PlainTextEditorView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDesignSystem
import StickiesDomain
import SwiftUI

struct PlainTextEditorView: View {
    @Environment(\.noteWorkspaceModel) private var workspace
    @Environment(\.colorScheme) private var colorScheme

    let noteID: NoteID

    var body: some View {
        StickyTextEditor(
            text: textBinding,
            fontName: metadata?.fontName,
            fontSize: metadata?.fontSize ?? NoteMetadata.Default.fontSize,
            fontColorHex: metadata?.fontColorHex
        )
        // The note's own color fills full-bleed behind the transparent editor, vivid in
        // light mode and a muted dark variant in dark mode. The text uses the primary
        // label color, which resolves dark on the light note and light on the dark note.
        .background(noteColor.backgroundColor(for: colorScheme).ignoresSafeArea())
        .contextMenu {
            ColorPickerMenuItems(noteID: noteID)
        }
    }

    private var metadata: NoteMetadata? {
        workspace?.note(for: noteID)?.metadata
    }

    private var noteColor: NoteColor {
        metadata?.colorName ?? .default
    }

    private var textBinding: Binding<String> {
        workspace?.binding(for: noteID) ?? .constant("")
    }
}
