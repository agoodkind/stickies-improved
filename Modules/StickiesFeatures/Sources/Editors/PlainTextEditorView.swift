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
        /// Height of the top glass frost. Tall enough to read under the floating traffic
        /// lights; the bottom of the band fades out so it blends into the note.
        static let frostHeight: CGFloat = 60
        /// Opacity of the frost at the window edge. Starts partial (never fully opaque) so the
        /// band reads as a soft frosted edge, then the gradient fades it to clear.
        static let frostEdgeOpacity: Double = 0.7
    }

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
        // Fill the window past the safe area so the editor's own top and left insets
        // place the first glyph at the measured 32pt/5pt, independent of the titlebar.
        .ignoresSafeArea()
        .background(noteColor.backgroundColor(for: colorScheme).ignoresSafeArea())
        .overlay(alignment: .top) {
            frostBand
        }
        .contextMenu {
            ColorPickerMenuItems(noteID: noteID)
        }
    }

    /// A Liquid Glass frost pinned to the top of the note, under the floating traffic lights.
    /// It uses the plain `.regular` system material with no bright tint, so in dark mode it is a
    /// dark, translucent glass that shows the material's refraction as text scrolls up past it,
    /// rather than a solid colored bar. The gradient is densest at the top edge and fades to
    /// clear toward the body, so it reads as a soft frosted edge. The bottom edge is left clean:
    /// a matching bottom frost dimmed the last lines and hurt readability. `glassEffect` is the
    /// system material, so the frost itself is not hand-drawn.
    private var frostBand: some View {
        Rectangle()
            .fill(.clear)
            .glassEffect(.regular, in: Rectangle())
            .frame(maxWidth: .infinity)
            .frame(height: Layout.frostHeight)
            .mask(
                LinearGradient(
                    colors: [.black.opacity(Layout.frostEdgeOpacity), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .top)
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
