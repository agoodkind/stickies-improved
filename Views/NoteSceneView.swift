//
//  NoteSceneView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesImprovedCore
import SwiftUI

struct NoteSceneView: View {
    private enum Layout {
        static let minWidth: CGFloat = 200
        static let idealWidth: CGFloat = 400
        static let minHeight: CGFloat = 200
        static let idealHeight: CGFloat = 400
    }

    @Environment(NoteWorkspaceStore.self) private var workspace
    @Environment(NoteWindowStateStore.self) private var windowStateStore

    @Binding var noteID: NoteID?

    var body: some View {
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
        .navigationTitle(noteID.map(workspace.displayTitle(for:)) ?? "Note")
        .containerBackground(.clear, for: .window)
        .background(StickyWindowChromeBridge())
        .onAppear {
            if let noteID {
                windowStateStore.noteWindowOpened(noteID)
            }
        }
        .onDisappear {
            if let noteID {
                windowStateStore.noteWindowClosed(noteID)
            }
        }
    }
}
