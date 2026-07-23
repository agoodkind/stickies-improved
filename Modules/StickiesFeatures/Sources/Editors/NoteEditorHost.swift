//
//  NoteEditorHost.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDesignSystem
import StickiesDomain
import SwiftUI
import UniformTypeIdentifiers

// MARK: - NoteEditorKind

enum NoteEditorKind: Equatable {
  case markdown
  case plainText
}

// MARK: - NoteEditorPresentation

struct NoteEditorPresentation: Equatable {
  let mode: NoteMode
  let noteColor: NoteColor
  let isCollapsed: Bool

  init(metadata: NoteMetadata?, isCollapsed: Bool) {
    let persistedCollapsed = metadata?.collapsed ?? false
    mode = metadata?.mode ?? .plainText
    noteColor = metadata?.colorName ?? .default
    self.isCollapsed = isCollapsed || persistedCollapsed
  }

  var editorKind: NoteEditorKind? {
    guard !isCollapsed else {
      return nil
    }
    switch mode {
    case .plainText:
      return .plainText
    case .markdown:
      return .markdown
    }
  }

  var showsEditorContent: Bool {
    editorKind != nil
  }
}

// MARK: - NoteEditorHost

struct NoteEditorHost: View {
  @Environment(\.noteWorkspaceModel) private var workspace
  @Environment(\.colorScheme) private var colorScheme

  let noteID: NoteID
  let isCollapsed: Bool

  // Drives the `.fileExporter` for this note window. The File-menu command flips
  // it through the published `noteExportTrigger` focused value.
  @State private var isExporting = false

  init(noteID: NoteID, isCollapsed: Bool = false) {
    self.noteID = noteID
    self.isCollapsed = isCollapsed
  }

  var body: some View {
    content
      .focusedValue(\.noteExportTrigger, $isExporting)
      .fileExporter(
        isPresented: $isExporting,
        document: PlainTextDocument(text: exportText),
        contentType: .plainText,
        defaultFilename: exportFilename
      ) { _ in
        // The exporter reports success or a user cancellation; the note
        // stays on disk either way, so there is nothing to persist here.
      }
  }

  @ViewBuilder private var content: some View {
    if let editorKind = presentation.editorKind {
      switch editorKind {
      case .plainText:
        PlainTextEditorView(noteID: noteID)
      case .markdown:
        MarkdownEditorView()
      }
    } else {
      presentation.noteColor.backgroundColor(for: colorScheme).ignoresSafeArea()
    }
  }

  private var exportText: String {
    workspace?.note(for: noteID)?.plainText ?? ""
  }

  private var exportFilename: String {
    let title = workspace?.displayTitle(for: noteID) ?? ExportFilename.fallback
    return ExportFilename.sanitized(title)
  }

  private var presentation: NoteEditorPresentation {
    NoteEditorPresentation(
      metadata: workspace?.note(for: noteID)?.metadata,
      isCollapsed: isCollapsed
    )
  }
}
