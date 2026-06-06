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
            fontColorHex: metadata?.fontColorHex
        )
        // Fill the window past the safe area so the editor's own top and left insets
        // place the first glyph at the measured 32pt/5pt, independent of the titlebar.
        .ignoresSafeArea()
        // Native Liquid Glass tinted with the note's color, so the note reads as a
        // frosted glass panel in the system material rather than a flat fill.
        .background(noteGlass)
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

    /// Full-bleed Liquid Glass tinted with the note's color. The note window is already
    /// a clear container, so the system samples what is behind it for the frosted look.
    private var noteGlass: some View {
        Rectangle()
            .fill(.clear)
            .glassEffect(.regular.tint(noteColor.swatchColor), in: Rectangle())
            .ignoresSafeArea()
    }

    private var textBinding: Binding<String> {
        workspace?.binding(for: noteID) ?? .constant("")
    }
}
