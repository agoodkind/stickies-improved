//
//  ManagerView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDesignSystem
import StickiesDomain
import SwiftUI

/// The "All Notes" manager window. A master-detail browser: the sidebar lists every
/// note in two sections, active notes under "Notes" and soft-deleted notes under
/// "Trash", and the detail pane previews whichever row is selected. A single click
/// selects and previews, a double-click or the default key opens the note in its own
/// floating window. Search collapses the sidebar to a single results section while the
/// preview pane keeps showing the selected note's full text.
public struct ManagerView: View {
  private enum Layout {
    static let swatchSize: CGFloat = 14
    static let emptySectionVerticalPadding: CGFloat = 6
    static let snippetLineLimit = 2
    static let inspectorMinWidth: CGFloat = 320
    static let inspectorIdealWidth: CGFloat = 380
    static let inspectorMaxWidth: CGFloat = 600
    static let rowSpacing: CGFloat = 10
    static let newNoteIconNudge: CGFloat = 1
  }

  private static let updatedDateStyle = Date.FormatStyle.dateTime
    .year().month().day().hour().minute()

  @Environment(\.noteWorkspaceModel) private var workspace
  @Environment(\.preferencesModel) private var preferences
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismissWindow) private var dismissWindow

  @State private var pendingPermanentDelete: NoteID?
  @State private var query = ""
  @State private var selection: NoteID?
  @State private var isPreviewVisible = false
  @State private var searchResults: [NoteSearchResult] = []
  @State private var isSearchRunning = false
  @State private var searchRunner = NoteSearchRunner()

  public init() {
    // Reads the workspace model from the environment.
  }

  public var body: some View {
    sidebar
      .navigationTitle("All Notes")
      .searchable(text: $query, prompt: "Search notes")
      .toolbar {
        newNoteButton
        previewToggle
      }
      .task(id: query) { await runSearch() }
      .onChange(of: selection) { _, newValue in
        // Selecting a note opens the preview; the toggle and dismissals only
        // flip visibility, so the selection survives a manual close.
        if newValue != nil {
          isPreviewVisible = true
        }
      }
      .inspector(isPresented: previewPresented) {
        previewInspector
      }
      .confirmationDialog(
        "Delete this note permanently?",
        isPresented: permanentDeleteBinding,
        titleVisibility: .visible
      ) {
        Button("Delete Permanently", role: .destructive) {
          confirmPermanentDelete()
        }
        Button("Cancel", role: .cancel) {
          pendingPermanentDelete = nil
        }
      } message: {
        Text("This removes the note from disk and cannot be undone.")
      }
  }

  // MARK: - Sidebar

  /// While searching, a single "Results" section replaces the two note sections; an
  /// empty query restores the normal sectioned list. The selection binding is shared
  /// across both layouts, so the preview stays put when the query clears.
  @ViewBuilder private var sidebar: some View {
    List(selection: $selection) {
      if isSearching {
        searchSection
      } else {
        notesSection
        trashSection
      }
    }
    // Single-click selection is the list's own behavior; a double-click opens the
    // selected note through one AppKit recognizer rather than per-row gestures.
    .background(ListRowDoubleClick { openSelected() })
  }

  private var isSearching: Bool {
    !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  @ViewBuilder private var searchSection: some View {
    Section("Results") {
      if isSearchRunning {
        HStack(spacing: Layout.rowSpacing) {
          ProgressView().controlSize(.small)
          Text("Searching\u{2026}").foregroundStyle(.secondary)
        }
        .padding(.vertical, Layout.emptySectionVerticalPadding)
      } else if searchResults.isEmpty {
        emptyRow("No matches")
      } else {
        ForEach(searchResults) { result in
          searchRow(for: result)
        }
      }
    }
  }

  /// Runs the full-text search off the render path: a short debounce coalesces
  /// keystrokes, then the matching runs on a background task over a Sendable snapshot
  /// so a large library never blocks the main thread. `.task(id: query)` cancels and
  /// restarts this whenever the query changes.
  private func runSearch() async {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      isSearchRunning = false
      searchResults = []
      return
    }
    isSearchRunning = true
    let active = workspace?.activeNotes ?? []
    let trashed = workspace?.trashedNotes ?? []
    let currentQuery = query
    let results = await searchRunner.search(
      active: active, trashed: trashed, query: currentQuery
    )
    guard !Task.isCancelled else { return }
    searchResults = results
    isSearchRunning = false
  }

  @ViewBuilder private var notesSection: some View {
    Section("Notes") {
      if let workspace, !workspace.activeNotes.isEmpty {
        ForEach(workspace.activeNotes) { note in
          activeRow(for: note)
        }
      } else {
        emptyRow("No notes")
      }
    }
  }

  @ViewBuilder private var trashSection: some View {
    Section("Trash") {
      if let workspace, !workspace.trashedNotes.isEmpty {
        ForEach(workspace.trashedNotes) { note in
          trashedRow(for: note)
        }
      } else {
        emptyRow("Trash is empty")
      }
    }
  }

  @ViewBuilder private func activeRow(for note: NoteDocument) -> some View {
    rowContent(for: note)
      .tag(note.id)
      .contextMenu {
        Button("Open") { openWindow(value: note.id) }
        Button("Move to Trash") { trash(note.id) }
      }
      .swipeActions(edge: .trailing) {
        Button("Trash", role: .destructive) { trash(note.id) }
      }
  }

  @ViewBuilder private func trashedRow(for note: NoteDocument) -> some View {
    rowContent(for: note)
      .tag(note.id)
      .contextMenu {
        Button("Restore") { restoreAndOpen(note.id) }
        Button("Delete Permanently", role: .destructive) {
          pendingPermanentDelete = note.id
        }
      }
      .swipeActions(edge: .trailing) {
        Button("Delete", role: .destructive) {
          pendingPermanentDelete = note.id
        }
        Button("Restore") { restoreAndOpen(note.id) }
          .tint(.green)
      }
  }

  private func rowContent(for note: NoteDocument) -> some View {
    HStack(spacing: Layout.rowSpacing) {
      NoteColorSwatch(note.metadata.colorName, size: Layout.swatchSize)
      VStack(alignment: .leading) {
        Text(note.metadata.title)
          .lineLimit(1)
        Text(note.metadata.updatedAt, format: Self.updatedDateStyle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  /// A single search-result row: color swatch, title, the context snippet, and a
  /// "Trash" badge when the hit lives in the trash. The row tags the note id so a
  /// single click previews it; a double-click on the selection opens the note.
  @ViewBuilder private func searchRow(for result: NoteSearchResult) -> some View {
    HStack(spacing: Layout.rowSpacing) {
      NoteColorSwatch(result.color, size: Layout.swatchSize)
      VStack(alignment: .leading) {
        HStack {
          Text(result.title)
            .lineLimit(1)
          if result.isTrashed {
            TrashBadge()
          }
        }
        Text(result.snippet)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(Layout.snippetLineLimit)
      }
    }
    .tag(result.noteID)
  }

  private func emptyRow(_ text: String) -> some View {
    Text(text)
      .foregroundStyle(.secondary)
      .padding(.vertical, Layout.emptySectionVerticalPadding)
  }

  // MARK: - Preview inspector

  private var selectedDocument: NoteDocument? {
    guard let selection else { return nil }
    return workspace?.anyDocument(for: selection)
  }

  /// Presents the inspector only while a note is selected and the preview is toggled
  /// on, so the window is a plain full-width list until a row is chosen. A manual
  /// close flips visibility without clearing the selection, so the list highlight
  /// stays and the toggle can reopen the same note.
  private var previewPresented: Binding<Bool> {
    Binding(
      get: { isPreviewVisible && selectedDocument != nil },
      set: { isPreviewVisible = $0 }
    )
  }

  /// Creates a note in the configured default color, mirroring the ⌘N command, then
  /// opens its window and selects its row so the manager and the new note stay in sync.
  @ToolbarContentBuilder private var newNoteButton: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      Button(action: createNote) {
        // `square.and.pencil`'s pencil extends past the top-right of the square, so
        // the glyph's ink sits low-left of its layout box and reads off-center in a
        // round toolbar button. A 1pt up-right nudge optically recenters it.
        Label {
          Text("New Note")
        } icon: {
          Image(systemName: "square.and.pencil")
            .offset(x: Layout.newNoteIconNudge, y: -Layout.newNoteIconNudge)
        }
      }
      .disabled(workspace == nil)
    }
  }

  /// The standard trailing-inspector toggle, enabled only when a note is selected so
  /// there is always something to preview when it opens.
  @ToolbarContentBuilder private var previewToggle: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      Button {
        isPreviewVisible.toggle()
      } label: {
        Label("Toggle Preview", systemImage: "sidebar.right")
      }
      .disabled(selectedDocument == nil)
    }
  }

  @ViewBuilder private var previewInspector: some View {
    if let document = selectedDocument {
      NotePreviewView(
        note: document,
        onOpen: { openWindow(value: document.id) },
        onRestore: { restoreAndOpen(document.id) },
        onTrash: { trash(document.id) },
        onDeletePermanently: { pendingPermanentDelete = document.id }
      )
      .inspectorColumnWidth(
        min: Layout.inspectorMinWidth,
        ideal: Layout.inspectorIdealWidth,
        max: Layout.inspectorMaxWidth
      )
    }
  }

  // MARK: - Actions

  private func createNote() {
    guard let workspace else { return }
    let color = preferences?.defaultColor ?? .default
    Task {
      let noteID = await workspace.createNote(color: color)
      openWindow(value: noteID)
      selection = noteID
    }
  }

  /// Opens the currently selected note in its own window, restoring it first when the
  /// selection is a trashed note. Invoked by the list's double-click recognizer, which
  /// fires after the first click has already set the selection.
  private func openSelected() {
    guard let id = selection, let document = workspace?.anyDocument(for: id) else {
      return
    }
    if document.metadata.isTrashed {
      restoreAndOpen(id)
    } else {
      openWindow(value: id)
    }
  }

  private func restoreAndOpen(_ noteID: NoteID) {
    // Restore moves the note back into the active set, then the window opens it;
    // opening only works for active notes, so the order matters.
    workspace?.restoreNote(noteID)
    openWindow(value: noteID)
  }

  private func trash(_ noteID: NoteID) {
    // Close the note's window if it is open so the soft delete also dismisses the
    // editor, then flip the model state so it leaves the active set.
    dismissWindow(value: noteID)
    workspace?.trashNote(noteID)
  }

  private func confirmPermanentDelete() {
    guard let noteID = pendingPermanentDelete else { return }
    pendingPermanentDelete = nil
    if selection == noteID {
      selection = nil
    }
    Task { await workspace?.deleteNotePermanently(noteID) }
  }

  private var permanentDeleteBinding: Binding<Bool> {
    Binding(
      get: { pendingPermanentDelete != nil },
      set: { isPresented in
        if !isPresented {
          pendingPermanentDelete = nil
        }
      }
    )
  }
}
