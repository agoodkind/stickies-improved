//
//  SettingsView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDomain
import SwiftUI

public struct SettingsView: View {
    private enum Layout {
        static let formPadding: CGFloat = 20
        static let windowWidth: CGFloat = 520
    }

    @Environment(\.noteWorkspaceModel) private var workspace
    @Environment(\.updaterModel) private var updaterModel
    @Environment(\.runtimeInfo) private var runtimeInfo

    public init() {
        // Reads everything from the environment.
    }

    public var body: some View {
        Form {
            Section("Storage") {
                LabeledContent("Bundle ID", value: runtimeInfo.bundleIdentifier)
                LabeledContent(
                    "iCloud Container",
                    value: runtimeInfo.iCloudContainerIdentifier
                )
                LabeledContent(
                    "Current Root",
                    value: workspace?.storageLocationDescription ?? "Loading..."
                )
            }

            Section("Editor") {
                LabeledContent("Enabled Mode", value: "Plain Text")
                LabeledContent("Future Mode", value: "Markdown (not yet implemented)")
            }

            Section("Updates") {
                LabeledContent("Feed URL", value: runtimeInfo.sparkleFeedURL)
                Button("Check for Updates") {
                    updaterModel?.checkForUpdates()
                }
            }
        }
        .padding(Layout.formPadding)
        .frame(width: Layout.windowWidth)
    }
}
