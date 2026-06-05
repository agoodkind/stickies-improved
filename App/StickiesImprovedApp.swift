//
//  StickiesImprovedApp.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesImprovedCore
import SwiftUI

@main
struct StickiesImprovedApp: App {
    private enum Layout {
        // Recovered from the original Stickie.nib: default content size 400x400.
        static let defaultNoteWindowWidth: CGFloat = 400
        static let defaultNoteWindowHeight: CGFloat = 400
    }

    @State private var workspace = NoteWorkspaceStore()
    @State private var windowStateStore = NoteWindowStateStore()
    @State private var appUpdater = AppUpdater(enabled: !RuntimeEnvironment.isRunningTests)

    var body: some Scene {
        WindowGroup(id: "launcher") {
            BootstrapView()
                .environment(workspace)
                .environment(windowStateStore)
                .environment(appUpdater)
        }
        .defaultSize(width: 1, height: 1)
        .windowResizability(.contentSize)

        WindowGroup("Note", for: NoteID.self) { $noteID in
            NoteSceneView(noteID: $noteID)
                .environment(workspace)
                .environment(windowStateStore)
                .environment(appUpdater)
        }
        .defaultSize(
            width: Layout.defaultNoteWindowWidth,
            height: Layout.defaultNoteWindowHeight
        )
        // Hide the SwiftUI titlebar so the note color fills full-bleed under the
        // floating standard traffic lights, matching the original's transparent
        // titlebar + fullSizeContentView chrome.
        .windowStyle(.hiddenTitleBar)
        .commands {
            NoteCommands(workspace: workspace, appUpdater: appUpdater)
        }

        Settings {
            SettingsView()
                .environment(workspace)
                .environment(appUpdater)
        }

        Window("About", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}
