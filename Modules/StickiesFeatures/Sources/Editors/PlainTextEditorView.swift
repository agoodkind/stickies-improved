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

    let noteID: NoteID

    var body: some View {
        StickyTextEditor(
            text: textBinding,
            fontName: metadata?.fontName,
            fontSize: metadata?.fontSize ?? NoteMetadata.Default.fontSize,
            fontColorHex: metadata?.fontColorHex,
            onFontChange: { name, size in
                workspace?.updateFont(name: name, size: size, for: noteID)
            },
            onColorChange: { hex in
                workspace?.updateFontColor(hex: hex, for: noteID)
            }
        )
        // The note's own color fills full-bleed behind the transparent editor; the
        // yellow default is the original `-[StickieBackgroundView getYellowColour]`.
        .background(noteColor.color.ignoresSafeArea())
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
