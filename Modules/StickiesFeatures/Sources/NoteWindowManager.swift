//
//  NoteWindowManager.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 18/06/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
import StickiesDomain
import SwiftUI

/// Owns the per-note windows as AppKit `NSPanel`s instead of a SwiftUI
/// `WindowGroup`. A plain `NSPanel` returns `canBecomeMain == false`, so when the
/// app activates (which is what clicking a background note does) macOS raises only
/// the *main and key* windows; since no note can be main, only the clicked (key)
/// note rises and the other notes keep their order. A `WindowGroup` note could
/// become the app's main window, which is what let a different note land on top of
/// the one that was clicked.
///
/// Each panel hosts the existing `NoteSceneView` through `NSHostingController`, so
/// the editor, chrome (`StickyWindowChromeBridge`), fold, frame persistence,
/// export, and open-window state tracking are reused unchanged. The content is
/// built by a closure the App supplies, which injects the model environment, so
/// this type stays decoupled from the concrete model graph.
@preconcurrency
@MainActor
public final class NoteWindowManager {
  private enum Layout {
    static let defaultWidth: CGFloat = 400
    static let defaultHeight: CGFloat = 400
  }

  private var panels: [NoteID: NSPanel] = [:]
  private var closeObservers: [NoteID: NSObjectProtocol] = [:]
  private let makeContent: @MainActor (NoteID) -> AnyView

  /// - Parameter makeContent: Builds the hosted SwiftUI view for a note id with the
  ///   model environment already injected. The App owns the model graph, so it
  ///   supplies this closure.
  @preconcurrency
  public init(makeContent: @escaping @MainActor (NoteID) -> AnyView) {
    self.makeContent = makeContent
  }

  /// Opens the note's panel, or brings it to the front and makes it key if it is
  /// already open. The front/key dedup matches what SwiftUI's `openWindow(value:)`
  /// gave for free.
  public func open(_ noteID: NoteID) {
    if let panel = panels[noteID] {
      panel.makeKeyAndOrderFront(nil)
      return
    }
    let panel = makePanel(for: noteID)
    panels[noteID] = panel
    observeClose(of: panel, noteID: noteID)
    panel.makeKeyAndOrderFront(nil)
  }

  /// Closes the note's panel if it is open. The hosted `NoteSceneView`'s
  /// `onDisappear` records the closed window in `NoteWindowStateModel`, and the
  /// close observer drops the panel from the manager.
  public func close(_ noteID: NoteID) {
    panels[noteID]?.close()
  }

  private func makePanel(for noteID: NoteID) -> NSPanel {
    let hosting = NSHostingController(rootView: makeContent(noteID))
    let panel = NSPanel(contentViewController: hosting)
    // Set the full recovered style mask up-front so the panel never briefly shows
    // wrong chrome before StickyWindowChromeBridge runs its async configuration.
    // This matches the mask the bridge applies (it only adds the transparent-
    // titlebar full-bleed appearance on top).
    panel.styleMask = [
      .titled,
      .closable,
      .miniaturizable,
      .resizable,
      .fullSizeContentView,
    ]
    panel.setContentSize(NSSize(width: Layout.defaultWidth, height: Layout.defaultHeight))
    // Notes are persistent desktop windows, not transient tool palettes: keep them
    // visible when the app deactivates.
    panel.hidesOnDeactivate = false
    // The manager holds the only strong reference, so closing must not also release
    // the panel out from under the close observer.
    panel.isReleasedWhenClosed = false
    return panel
  }

  private func observeClose(of panel: NSPanel, noteID: NoteID) {
    let observer = NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification,
      object: panel,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.forget(noteID)
      }
    }
    closeObservers[noteID] = observer
  }

  private func forget(_ noteID: NoteID) {
    if let observer = closeObservers[noteID] {
      NotificationCenter.default.removeObserver(observer)
    }
    closeObservers[noteID] = nil
    panels[noteID] = nil
  }
}

// MARK: - EnvironmentValues

extension EnvironmentValues {
  // Set by the App composition root and read by `BootstrapView` and `ManagerView`
  // to open and close note panels. `NoteCommands` takes the manager by init
  // parameter instead, since custom environment is not reliably available to
  // `Commands`.
  public var noteWindowManager: NoteWindowManager? {
    get { storedNoteWindowManager }
    set { storedNoteWindowManager = newValue }
  }

  // The private `@Entry`-backed accessor gives this extension mixed access levels,
  // which keeps both swiftlint and swift-format from fighting over an access
  // modifier on the extension keyword (the same trick as FocusedValues+NoteID).
  @Entry private var storedNoteWindowManager: NoteWindowManager?
}
