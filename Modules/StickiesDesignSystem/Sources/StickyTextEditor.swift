//
//  StickyTextEditor.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import SwiftUI

/// A native SwiftUI plain-text editor that reproduces the original Plain Text Stickies
/// note body: one uniform font, size, and text color across the whole note, not rich
/// text. The editor draws no background so the per-note color shows through, and its
/// font and color come from the environment rather than per-range attributes, which is
/// what keeps the whole note uniform.
public struct StickyTextEditor: View {
    /// Insets tuned against a real Plain Text Stickies note, where the first text line
    /// sits about 32pt below the window top, clearing the floating traffic lights, with a
    /// 5pt left margin. SwiftUI insets the note content below the hidden titlebar by the
    /// window safe area, and `TextEditor` adds its own text-container inset, which together
    /// overshoot the target; these negative nudges pull the first glyph back to the
    /// measured 32pt top and 5pt left.
    private enum Layout {
        static let topInset: CGFloat = -3
        static let leadingInset: CGFloat = -1
    }

    @Binding private var text: String
    private let fontName: String?
    private let fontSize: Double
    private let fontColorHex: String?

    /// The editor's own source of truth. `TextEditor` needs an `AttributedString`, while
    /// the model stores a plain `String`, so this state bridges the two and is kept in
    /// sync with the binding through the two `onChange` handlers below.
    @State private var attributed: AttributedString

    public init(
        text: Binding<String>,
        fontName: String?,
        fontSize: Double,
        fontColorHex: String?
    ) {
        _text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontColorHex = fontColorHex
        _attributed = State(initialValue: AttributedString(text.wrappedValue))
    }

    public var body: some View {
        TextEditor(text: $attributed)
            .font(noteFont)
            .foregroundStyle(noteColor)
            // Hide the editor's own background so the per-note color painted behind it
            // shows through, matching the full-bleed pastel note.
            .scrollContentBackground(.hidden)
            .padding(.top, Layout.topInset)
            .padding(.leading, Layout.leadingInset)
            .onChange(of: attributed) {
                // Push edits back to the model as plain text. The guard stops the empty
                // round-trip that an external rebuild would otherwise cause.
                let plain = String(attributed.characters)
                if plain != text {
                    text = plain
                }
            }
            .onChange(of: text) {
                // Rebuild only when the model text genuinely diverges from the editor.
                // Skipping the no-op rebuild while the user types keeps the caret in
                // place, since reassigning `attributed` would collapse the selection.
                if String(attributed.characters) != text {
                    attributed = AttributedString(text)
                }
            }
    }

    /// Uniform note font: the system font when no family is pinned, otherwise the named
    /// family. `TextEditor` applies this to any run that carries no font of its own,
    /// which an `AttributedString` built from a plain string never does.
    private var noteFont: Font {
        guard let fontName else {
            return .system(size: fontSize)
        }
        return .custom(fontName, size: fontSize)
    }

    /// Uniform note text color: the user-picked hex when present, otherwise the primary
    /// label color, which resolves dark under the light color scheme the note pins.
    private var noteColor: Color {
        guard let fontColorHex, let resolved = HexColor.color(from: fontColorHex) else {
            return .primary
        }
        return resolved
    }
}
