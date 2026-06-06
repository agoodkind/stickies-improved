//
//  StickiesImprovedApp.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDomain
import StickiesFeatures
import StickiesPersistence
import SwiftUI

@main
struct StickiesImprovedApp: App {
    private enum Layout {
        // Recovered from the original Stickie.nib: default content size 400x400.
        static let defaultNoteWindowWidth: CGFloat = 400
        static let defaultNoteWindowHeight: CGFloat = 400
        // The manager is a modern list window, sized to comfortably show a handful
        // of note rows across both sections.
        static let managerWindowWidth: CGFloat = 480
        static let managerWindowHeight: CGFloat = 520
    }

    private static let managerWindowID = "manager"

    @NSApplicationDelegateAdaptor(StickiesAppDelegate.self) private var appDelegate

    private let runtimeInfo = BundleRuntimeInfo()

    @State private var workspace: NoteWorkspaceModel
    @State private var windowStateModel = NoteWindowStateModel()
    @State private var updaterModel: UpdaterModel
    @State private var preferencesModel = PreferencesModel()

    init() {
        let info = BundleRuntimeInfo()
        let resolver = StorageLocationResolver(
            iCloudContainerIdentifier: info.iCloudContainerIdentifier,
            localFolderName: info.bundleIdentifier
        )
        let noteStore = FilePackageNoteStore(
            locationResolver: resolver,
            contentCodec: IdentityContentCodec(),
            loggerSubsystem: info.bundleIdentifier
        )
        let libraryMonitor = UbiquityLibraryMonitor()
        let scheduler = ContinuousClockAutosaveScheduler()
        let migrator = FileLibraryMigrator(
            resolver: resolver,
            loggerSubsystem: info.bundleIdentifier
        )
        _ = NoopActivityPublisher()

        _workspace = State(
            initialValue: NoteWorkspaceModel(
                noteStore: noteStore,
                libraryMonitor: libraryMonitor,
                autosaveScheduler: scheduler,
                libraryMigrator: migrator,
                loggerSubsystem: info.bundleIdentifier
            )
        )

        let updaterController = SparkleUpdaterController(
            enabled: !RuntimeEnvironment.isRunningTests
        )
        _updaterModel = State(
            initialValue: UpdaterModel(controller: updaterController)
        )
    }

    var body: some Scene {
        WindowGroup(id: "launcher") {
            injectModels(into: BootstrapView())
                .background(ReopenBridge(managerWindowID: Self.managerWindowID))
        }
        .defaultSize(width: 1, height: 1)
        .windowResizability(.contentSize)

        WindowGroup("Note", for: NoteID.self) { $noteID in
            injectModels(into: NoteSceneView(noteID: $noteID))
        }
        .defaultSize(
            width: Layout.defaultNoteWindowWidth,
            height: Layout.defaultNoteWindowHeight
        )
        // Hide the SwiftUI titlebar so the note color fills full-bleed under the
        // floating standard traffic lights, matching the original's transparent
        // titlebar + fullSizeContentView chrome.
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            NoteCommands(
                workspace: workspace,
                updaterModel: updaterModel,
                preferences: preferencesModel
            )
        }

        Window("All Notes", id: Self.managerWindowID) {
            injectModels(into: ManagerView())
        }
        .defaultSize(
            width: Layout.managerWindowWidth,
            height: Layout.managerWindowHeight
        )
        .windowResizability(.contentMinSize)

        Settings {
            injectModels(into: SettingsRootView())
        }

        Window("About", id: "about") {
            injectModels(into: AboutView())
        }
        .windowResizability(.contentSize)
    }

    // Captures the scene's `openWindow` action into the app delegate so a dock-icon reopen
    // can restore the manager window after every note has closed. The launcher scene that
    // hosts this lives for the app's lifetime, so the captured action stays valid.
    private struct ReopenBridge: View {
        @Environment(\.openWindow) private var openWindow
        let managerWindowID: String

        var body: some View {
            Color.clear
                .frame(width: 0, height: 0)
                .onAppear {
                    StickiesAppDelegate.openManager = {
                        openWindow(id: managerWindowID)
                    }
                }
        }
    }

    // Inject every model and service the feature layer reads. Keeping the keys
    // here means the App is the only place that knows the concrete graph.
    private func injectModels(into content: some View) -> some View {
        content
            .environment(\.noteWorkspaceModel, workspace)
            .environment(\.noteWindowStateModel, windowStateModel)
            .environment(\.updaterModel, updaterModel)
            .environment(\.preferencesModel, preferencesModel)
            .environment(\.runtimeInfo, runtimeInfo)
    }
}
