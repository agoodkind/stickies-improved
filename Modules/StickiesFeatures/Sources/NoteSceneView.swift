//
//  NoteSceneView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDesignSystem
import StickiesDomain
import SwiftUI

public struct NoteSceneView: View {
  private enum Layout {
    static let minWidth: CGFloat = 200
    static let idealWidth: CGFloat = 400
    // The content can shrink to the titlebar strip when the note is folded, so the
    // SwiftUI content minimum height must not impose a tall floor that would clamp
    // the collapse. The fold target is the titlebar height (about 28pt), so a small
    // content minimum lets AppKit settle the collapsed frame.
    static let minHeight: CGFloat = 28
    static let idealHeight: CGFloat = 400
  }

  private enum Focus {
    /// Recovered `nonFocusTransparency` default: a focused note is fully opaque, an
    /// unfocused one drops to this alpha.
    static let unfocusedAlphaDefaultsKey = "nonFocusTransparency"
    static let unfocusedAlphaFallback: Double = 0.97
  }

  @Environment(\.noteWorkspaceModel) private var workspace
  @Environment(\.noteWindowStateModel) private var windowStateModel
  @Environment(\.appearsActive) private var appearsActive

  @Binding var noteID: NoteID?

  public init(noteID: Binding<NoteID?>) {
    _noteID = noteID
  }

  public var body: some View {
    Group {
      if let noteID {
        NoteEditorHost(noteID: noteID)
      } else {
        ContentUnavailableView("No Note", systemImage: "note.text")
      }
    }
    .frame(
      minWidth: Layout.minWidth,
      idealWidth: Layout.idealWidth,
      minHeight: Layout.minHeight,
      idealHeight: Layout.idealHeight
    )
    .navigationTitle(navigationTitle)
    .containerBackground(.clear, for: .window)
    .opacity(appearsActive ? 1.0 : unfocusedAlpha)
    .background(chromeBridge)
    .focusedSceneValue(\.focusedNoteID, noteID)
    .onAppear {
      if let noteID {
        windowStateModel?.noteWindowOpened(noteID)
      }
    }
    .onDisappear {
      if let noteID {
        windowStateModel?.noteWindowClosed(noteID)
      }
    }
  }

  private var navigationTitle: String {
    guard let noteID, let workspace else { return "Note" }
    return workspace.displayTitle(for: noteID)
  }

  private var unfocusedAlpha: Double {
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: Focus.unfocusedAlphaDefaultsKey) != nil else {
      return Focus.unfocusedAlphaFallback
    }
    return Double(defaults.float(forKey: Focus.unfocusedAlphaDefaultsKey))
  }

  /// Builds the chrome bridge for the active note, wiring fold and frame
  /// persistence to the workspace model. Falls back to the chrome-only bridge when
  /// there is no note or no workspace, so the placeholder window still gets chrome.
  @ViewBuilder private var chromeBridge: some View {
    if let noteID, let workspace {
      StickyWindowChromeBridge(
        noteID: noteID,
        savedFrame: { workspace.noteFrame(for: noteID) },
        onFrameChange: { frame in workspace.updateFrame(frame, for: noteID) },
        initialCollapsed: workspace.isCollapsed(for: noteID),
        expandedHeight: workspace.expandedHeight(for: noteID),
        onCollapseChange: { collapsed, height in
          workspace.setCollapsed(collapsed, expandedHeight: height, for: noteID)
        },
        collapsedTitle: { workspace.displayTitle(for: noteID) }
      )
    } else {
      StickyWindowChromeBridge()
    }
  }
}
