//
//  NoteEditorHost.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDomain
import SwiftUI
import UniformTypeIdentifiers

struct NoteEditorHost: View {
  @Environment(\.noteWorkspaceModel) private var workspace

  let noteID: NoteID

  // Drives the `.fileExporter` for this note window. The File-menu command flips
  // it through the published `noteExportTrigger` focused value.
  @State private var isExporting = false

  var body: some View {
    editor
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

  @ViewBuilder private var editor: some View {
    switch workspace?.note(for: noteID)?.metadata.mode ?? .plainText {
    case .plainText:
      PlainTextEditorView(noteID: noteID)
    case .markdown:
      MarkdownEditorView()
    }
  }

  private var exportText: String {
    workspace?.note(for: noteID)?.plainText ?? ""
  }

  private var exportFilename: String {
    let title = workspace?.displayTitle(for: noteID) ?? ExportFilename.fallback
    return ExportFilename.sanitized(title)
  }
}
