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
    // The manager is a modern list window, sized to comfortably show a handful
    // of note rows across both sections.
    static let managerWindowWidth: CGFloat = 480
    static let managerWindowHeight: CGFloat = 520
  }

  private static let managerWindowID = "manager"

  @NSApplicationDelegateAdaptor(StickiesAppDelegate.self) private var appDelegate

  private let runtimeInfo = BundleRuntimeInfo()

  @State private var workspace: NoteWorkspaceModel
  @State private var windowStateModel: NoteWindowStateModel
  @State private var updaterModel: UpdaterModel
  @State private var preferencesModel: PreferencesModel
  @State private var noteWindowManager: NoteWindowManager

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

    let workspaceModel = NoteWorkspaceModel(
      noteStore: noteStore,
      libraryMonitor: libraryMonitor,
      autosaveScheduler: scheduler,
      libraryMigrator: migrator,
      loggerSubsystem: info.bundleIdentifier
    )
    let windowState = NoteWindowStateModel()
    let preferences = PreferencesModel()
    let updater = UpdaterModel(
      controller: SparkleUpdaterController(
        enabled: !RuntimeEnvironment.isRunningTests
      )
    )

    _workspace = State(initialValue: workspaceModel)
    _windowStateModel = State(initialValue: windowState)
    _preferencesModel = State(initialValue: preferences)
    _updaterModel = State(initialValue: updater)

    // Note panels host `NoteSceneView` with the same model environment the App
    // injects elsewhere, so the editor, chrome, fold, and export all behave as
    // before. Capturing the model instances (not `self`) keeps this safe to build
    // during the struct's init.
    _noteWindowManager = State(
      initialValue: NoteWindowManager { noteID in
        AnyView(
          NoteSceneView(noteID: .constant(noteID))
            .environment(\.noteWorkspaceModel, workspaceModel)
            .environment(\.noteWindowStateModel, windowState)
            .environment(\.updaterModel, updater)
            .environment(\.preferencesModel, preferences)
            .environment(\.runtimeInfo, info)
        )
      }
    )
  }

  var body: some Scene {
    // The note windows are AppKit `NSPanel`s owned by `NoteWindowManager` (a panel
    // cannot become the app's main window, so clicking one note never raises the
    // others). The note menu commands live here on the always-present launcher
    // scene, since SwiftUI commands apply app-wide regardless of host scene.
    WindowGroup(id: "launcher") {
      injectModels(into: BootstrapView())
    }
    .defaultSize(width: 1, height: 1)
    .windowResizability(.contentSize)
    .commands {
      NoteCommands(
        workspace: workspace,
        updaterModel: updaterModel,
        preferences: preferencesModel,
        noteWindowManager: noteWindowManager
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

  // Captures the scene's `openWindow` action into the app delegate so a dock-icon reopen can
  // restore the manager window after every note has closed. It is attached to every injected
  // scene (not just the hidden launcher) so whichever window has appeared keeps the captured
  // action fresh, and a zero-size helper view never has to fire `onAppear`.
  private struct ReopenBridge: View {
    @Environment(\.openWindow) private var openWindow
    let managerWindowID: String

    var body: some View {
      Color.clear
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
      .environment(\.noteWindowManager, noteWindowManager)
      .environment(\.runtimeInfo, runtimeInfo)
      .background(ReopenBridge(managerWindowID: Self.managerWindowID))
  }
}
