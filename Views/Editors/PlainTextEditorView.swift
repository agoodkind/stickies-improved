//
//  PlainTextEditorView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesImprovedCore
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

    /// Default new-note color recovered from the original
    /// `-[StickieBackgroundView getYellowColour]` (sRGB).
    private enum Palette {
        static let yellowRed: Double = 0.98
        static let yellowGreen: Double = 0.90
        static let yellowBlue: Double = 0.45
    }

    @Environment(NoteWorkspaceStore.self) private var workspace

    let noteID: NoteID

    var body: some View {
        TextEditor(text: workspace.binding(for: noteID))
            .font(.system(size: Layout.fontSize))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, Layout.textHorizontalPadding)
            .padding(.bottom, Layout.textBottomPadding)
            .padding(.top, Layout.textTopPadding)
            .background(noteColor.ignoresSafeArea())
    }

    private var noteColor: Color {
        Color(
            red: Palette.yellowRed,
            green: Palette.yellowGreen,
            blue: Palette.yellowBlue
        )
    }
}
