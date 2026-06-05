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
    private enum Layout {
        static let textHorizontalPadding: CGFloat = 12
        static let textBottomPadding: CGFloat = 12
        // Keep the text clear of the transparent titlebar zone where the
        // standard traffic lights float, matching the original's content inset.
        static let textTopPadding: CGFloat = 30
        static let fontSize: CGFloat = 13
    }

    @Environment(\.noteWorkspaceModel) private var workspace

    let noteID: NoteID

    var body: some View {
        TextEditor(text: textBinding)
            .font(.system(size: Layout.fontSize))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, Layout.textHorizontalPadding)
            .padding(.bottom, Layout.textBottomPadding)
            .padding(.top, Layout.textTopPadding)
            // The note's own color fills full-bleed; the yellow default is the
            // original `-[StickieBackgroundView getYellowColour]` (sRGB).
            .background(noteColor.color.ignoresSafeArea())
            .contextMenu {
                ColorPickerMenuItems(noteID: noteID)
            }
    }

    private var noteColor: NoteColor {
        workspace?.note(for: noteID)?.metadata.colorName ?? .default
    }

    private var textBinding: Binding<String> {
        workspace?.binding(for: noteID) ?? .constant("")
    }
}
