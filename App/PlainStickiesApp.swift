import PlainStickiesCore
import SwiftUI

@main
struct PlainStickiesApp: App {
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
        .defaultSize(width: 300, height: 150)

        WindowGroup("Note", for: NoteID.self) { $noteID in
            NoteSceneView(noteID: $noteID)
                .environment(workspace)
                .environment(windowStateStore)
                .environment(appUpdater)
        }
        .defaultSize(width: 280, height: 240)
        .commands {
            NoteCommands()
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
