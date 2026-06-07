//
//  BootstrapView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
import StickiesApplication
import StickiesDomain
import SwiftUI

public struct BootstrapView: View {
  @Environment(\.noteWorkspaceModel) private var workspace
  @Environment(\.noteWindowStateModel) private var windowStateModel
  @Environment(\.openWindow) private var openWindow

  @State private var didOpenWindows = false

  public init() {
    // Stateless launcher view.
  }

  public var body: some View {
    Color.clear
      .frame(width: 1, height: 1)
      .task {
        guard !RuntimeEnvironment.isRunningTests else { return }
        guard !didOpenWindows else { return }
        guard let workspace, let windowStateModel else { return }
        didOpenWindows = true

        let noteIDs = await workspace.bootstrap(
          openNoteIDs: windowStateModel.openNoteIDs
        )
        for noteID in noteIDs {
          openWindow(value: noteID)
        }

        if !noteIDs.isEmpty {
          NSApp.activate(ignoringOtherApps: true)
        }
      }
  }
}
