//
//  SettingsRootView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import SwiftUI

/// The Settings window root, splitting preferences and the About pane into tabs so the
/// same `AboutView` content appears both here and in the standalone About window.
public struct SettingsRootView: View {
  public init() {
    // Reads everything its tabs need from the environment.
  }

  public var body: some View {
    TabView {
      SettingsView()
        .tabItem { Label("General", systemImage: "gearshape") }
      AboutView()
        .tabItem { Label("About", systemImage: "info.circle") }
    }
  }
}
