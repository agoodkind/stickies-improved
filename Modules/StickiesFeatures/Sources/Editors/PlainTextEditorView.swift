//
//  PlainTextEditorView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
import StickiesApplication
import StickiesDesignSystem
import StickiesDomain
import SwiftUI

struct PlainTextEditorView: View {
  @Environment(\.noteWorkspaceModel) private var workspace
  @Environment(\.noteWindowManager) private var noteWindowManager
  @Environment(\.colorScheme) private var colorScheme

  let noteID: NoteID

  var body: some View {
    StickyTextEditor(
      text: textBinding,
      fontName: metadata?.fontName,
      fontSize: metadata?.fontSize ?? NoteMetadata.Default.fontSize,
      fontColorHex: metadata?.fontColorHex,
      onCommandDelete: deleteNote
    )
    // Fill the window past the safe area so the editor's own top and left insets
    // place the first glyph at the measured 32pt/5pt, independent of the titlebar.
    .ignoresSafeArea()
    .background(noteColor.backgroundColor(for: colorScheme).ignoresSafeArea())
    // The top frost is an AppKit NSVisualEffectView inside StickyTextEditor, not a SwiftUI
    // overlay. A SwiftUI .glassEffect here only tinted, because it samples the SwiftUI
    // backdrop rather than the AppKit text rendered in the hosted scroll view; the
    // within-window blur view samples and blurs that text as it scrolls under the edge.
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

  private func deleteNote() {
    workspace?.trashNote(noteID)
    NSApp.keyWindow?.close()
    noteWindowManager?.close(noteID)
  }
}
