import StickiesImprovedCore
import SwiftUI

@main
struct StickiesImprovedApp: App {
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
        .defaultSize(width: 280, height: 240)
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
