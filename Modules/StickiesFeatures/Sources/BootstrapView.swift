//
//  BootstrapView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDomain
import SwiftUI

public struct BootstrapView: View {
  @Environment(\.noteWorkspaceModel) private var workspace
  @Environment(\.noteWindowStateModel) private var windowStateModel
  @Environment(\.noteWindowManager) private var noteWindowManager

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
        guard let workspace, let windowStateModel, let noteWindowManager else { return }
        didOpenWindows = true

        let noteIDs = await workspace.bootstrap(
          openNoteIDs: windowStateModel.openNoteIDs
        )
        for noteID in noteIDs {
          noteWindowManager.open(noteID)
        }
      }
  }
}
