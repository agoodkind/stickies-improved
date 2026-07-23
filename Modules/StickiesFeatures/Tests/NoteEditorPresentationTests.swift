//
//  NoteEditorPresentationTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 04/07/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain
import Testing

@testable import StickiesFeatures

@MainActor
struct NoteEditorPresentationTests {
  @Test func collapsedPlainTextNoteHidesEditorContentAndKeepsColor() {
    let metadata = NoteMetadata(
      id: NoteID(),
      mode: .plainText,
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 1),
      colorName: .green
    )

    let presentation = NoteEditorPresentation(metadata: metadata, isCollapsed: true)

    #expect(presentation.mode == .plainText)
    #expect(presentation.noteColor == .green)
    #expect(presentation.showsEditorContent == false)
    #expect(presentation.editorKind == nil)
  }

  @Test func expandedPlainTextNoteShowsEditorContent() {
    let metadata = NoteMetadata(
      id: NoteID(),
      mode: .plainText,
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 1),
      colorName: .yellow
    )

    let presentation = NoteEditorPresentation(metadata: metadata, isCollapsed: false)

    #expect(presentation.mode == .plainText)
    #expect(presentation.noteColor == .yellow)
    #expect(presentation.showsEditorContent)
    #expect(presentation.editorKind == .plainText)
  }

  @Test func collapsedMarkdownNoteHidesEditorContent() {
    let metadata = NoteMetadata(
      id: NoteID(),
      mode: .markdown,
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 1),
      colorName: .pink
    )

    let presentation = NoteEditorPresentation(metadata: metadata, isCollapsed: true)

    #expect(presentation.mode == .markdown)
    #expect(presentation.noteColor == .pink)
    #expect(presentation.showsEditorContent == false)
    #expect(presentation.editorKind == nil)
  }

  @Test func missingMetadataFallsBackToExpandedPlainTextDefaultColor() {
    let presentation = NoteEditorPresentation(metadata: nil, isCollapsed: false)

    #expect(presentation.mode == .plainText)
    #expect(presentation.noteColor == .default)
    #expect(presentation.showsEditorContent)
    #expect(presentation.editorKind == .plainText)
  }

  @Test func persistedCollapsedMetadataOverridesExpandedInput() {
    let metadata = NoteMetadata(
      id: NoteID(),
      mode: .plainText,
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 1),
      colorName: .orange,
      collapsed: true
    )

    let presentation = NoteEditorPresentation(metadata: metadata, isCollapsed: false)

    #expect(presentation.mode == .plainText)
    #expect(presentation.noteColor == .orange)
    #expect(presentation.isCollapsed)
    #expect(presentation.showsEditorContent == false)
    #expect(presentation.editorKind == nil)
  }
}
