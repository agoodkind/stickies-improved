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
        static let minHeight: CGFloat = 200
        static let idealHeight: CGFloat = 400
    }

    @Environment(\.noteWorkspaceModel) private var workspace
    @Environment(\.noteWindowStateModel) private var windowStateModel

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
        .background(StickyWindowChromeBridge())
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
}
