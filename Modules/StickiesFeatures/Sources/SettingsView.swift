//
//  SettingsView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDesignSystem
import StickiesDomain
import SwiftUI

public struct SettingsView: View {
    private enum Layout {
        static let formPadding: CGFloat = 20
        static let windowWidth: CGFloat = 520
        static let sliderMinWidth: CGFloat = 220
    }

    private enum Percent {
        static let minimumLabel = "50%"
        static let maximumLabel = "100%"
    }

    @Environment(\.noteWorkspaceModel) private var workspace
    @Environment(\.updaterModel) private var updaterModel
    @Environment(\.preferencesModel) private var preferences
    @Environment(\.runtimeInfo) private var runtimeInfo

    public init() {
        // Reads everything from the environment.
    }

    public var body: some View {
        Form {
            storageSection
            appearanceSection
            diagnosticsSection
            editorSection
            updatesSection
        }
        .formStyle(.grouped)
        .padding(Layout.formPadding)
        .frame(width: Layout.windowWidth)
    }

    @ViewBuilder private var storageSection: some View {
        Section("Storage") {
            Picker("Location", selection: storageModeBinding) {
                Text("On This Mac").tag(StorageMode.local)
                Text("iCloud").tag(StorageMode.iCloud)
            }
            LabeledContent("Bundle ID", value: runtimeInfo.bundleIdentifier)
            LabeledContent("iCloud Container", value: runtimeInfo.iCloudContainerIdentifier)
            LabeledContent(
                "Current Root",
                value: workspace?.storageLocationDescription ?? "Loading..."
            )
        }
    }

    @ViewBuilder private var appearanceSection: some View {
        Section("Appearance") {
            LabeledContent("Unfocused Transparency") {
                Slider(
                    value: transparencyBinding,
                    in: PreferencesModel.Bounds
                        .minimumTransparency...PreferencesModel.Bounds.maximumTransparency
                ) {
                    Text("Unfocused Transparency")
                } minimumValueLabel: {
                    Text(Percent.minimumLabel)
                } maximumValueLabel: {
                    Text(Percent.maximumLabel)
                }
                .frame(minWidth: Layout.sliderMinWidth)
            }

            Picker("New Note Color", selection: defaultColorBinding) {
                ForEach(NoteColor.allCases, id: \.self) { color in
                    Label {
                        Text(color.rawValue.capitalized)
                    } icon: {
                        color.swatchImage()
                    }
                    .tag(color)
                }
            }
        }
    }

    @ViewBuilder private var diagnosticsSection: some View {
        Section("Diagnostics") {
            Stepper(
                value: verbosityBinding,
                in: PreferencesModel.Bounds
                    .minimumVerbosity...PreferencesModel.Bounds.maximumVerbosity
            ) {
                LabeledContent("Log Verbosity", value: "\(verbosityBinding.wrappedValue)")
            }
        }
    }

    @ViewBuilder private var editorSection: some View {
        Section("Editor") {
            LabeledContent("Enabled Mode", value: "Plain Text")
            LabeledContent("Future Mode", value: "Markdown (not yet implemented)")
        }
    }

    @ViewBuilder private var updatesSection: some View {
        Section("Updates") {
            LabeledContent("Feed URL", value: runtimeInfo.sparkleFeedURL)
            Button("Check for Updates") {
                updaterModel?.checkForUpdates()
            }
        }
    }

    /// Switching the location persists the new mode first so the resolver points
    /// at the destination root, then migrates the packages and refreshes.
    private var storageModeBinding: Binding<StorageMode> {
        Binding(
            get: { preferences?.storageMode ?? .default },
            set: { newMode in
                guard let preferences, let workspace else { return }
                let oldMode = preferences.storageMode
                guard oldMode != newMode else { return }
                preferences.storageMode = newMode
                Task { await workspace.switchStorageMode(from: oldMode, to: newMode) }
            }
        )
    }

    private var transparencyBinding: Binding<Double> {
        Binding(
            get: {
                preferences?.unfocusedTransparency
                    ?? PreferencesModel.Bounds.maximumTransparency
            },
            set: { preferences?.unfocusedTransparency = $0 }
        )
    }

    private var defaultColorBinding: Binding<NoteColor> {
        Binding(
            get: { preferences?.defaultColor ?? .default },
            set: { preferences?.defaultColor = $0 }
        )
    }

    private var verbosityBinding: Binding<Int> {
        Binding(
            get: { preferences?.verbosity ?? PreferencesModel.Bounds.minimumVerbosity },
            set: { preferences?.verbosity = $0 }
        )
    }
}
