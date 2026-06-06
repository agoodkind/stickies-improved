//
//  AboutView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
import StickiesApplication
import StickiesDomain
import SwiftUI
import os

/// The shared About pane, used both as the standalone About window and as the Settings
/// "About" tab. It keeps the app hero, the Software Updates controls, contact links, and
/// the build details in one place so the two surfaces never drift.
public struct AboutView: View {
    private static let log = Logger(
        subsystem: "io.goodkind.stickies-improved", category: "About"
    )

    private enum Layout {
        static let formMaxWidth: CGFloat = 520
        static let heroIconSize: CGFloat = 96
        static let heroSpacing: CGFloat = 16
        static let heroTitleSpacing: CGFloat = 4
        static let statusSpacing: CGFloat = 2
        static let contactIconSpacing: CGFloat = 8
    }

    @Environment(\.runtimeInfo) private var runtimeInfo
    @Environment(\.updaterModel) private var updaterModel

    public init() {
        // Reads version info and the updater model from the environment.
    }

    public var body: some View {
        Form {
            heroSection
            softwareUpdatesSection
            contactSection
            buildDetailsSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: Layout.formMaxWidth)
    }

    private var heroSection: some View {
        Section {
            HStack(spacing: Layout.heroSpacing) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: Layout.heroIconSize, height: Layout.heroIconSize)
                VStack(alignment: .leading, spacing: Layout.heroTitleSpacing) {
                    Text("Stickies Improved")
                        .font(.title2.weight(.semibold))
                    Text("Plain-text notes with iCloud sync.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder private var softwareUpdatesSection: some View {
        Section("Software Updates") {
            Toggle("Automatically check for updates", isOn: automaticChecksBinding)
                .disabled(!isUpdaterConfigured)
            updateStatusRow
        }
    }

    @ViewBuilder private var updateStatusRow: some View {
        if let updaterModel, updaterModel.isConfigured {
            HStack {
                VStack(alignment: .leading, spacing: Layout.statusSpacing) {
                    Label(updateStatusLabel, systemImage: "arrow.triangle.2.circlepath.circle")
                        .symbolRenderingMode(.hierarchical)
                    Text("Updates are delivered automatically from goodkind.io.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Check Now") { updaterModel.checkForUpdates() }
                    .disabled(!updaterModel.canCheckForUpdates)
            }
        } else {
            Label("Software updates are available in release builds.", systemImage: "hammer")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
    }

    private var contactSection: some View {
        Section("Contact") {
            HStack {
                VStack(alignment: .leading, spacing: Layout.statusSpacing) {
                    Text("Alex Goodkind")
                        .font(.body.weight(.semibold))
                    Text("alex@goodkind.io")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: Layout.contactIconSpacing) {
                    linkButton("envelope.fill", "Email", "mailto:alex@goodkind.io")
                    linkButton("globe", "Website", "https://goodkind.io")
                    linkButton(
                        "chevron.left.forwardslash.chevron.right",
                        "Source",
                        "https://github.com/agoodkind/stickies-improved"
                    )
                }
            }
        }
    }

    private var buildDetailsSection: some View {
        Section("Build Details") {
            keyValueRow("Version", runtimeInfo.marketingVersion)
            keyValueRow("Build", runtimeInfo.buildVersion)
            keyValueRow("Branch", runtimeInfo.gitBranch)
            keyValueRow("Built", runtimeInfo.buildDate)
        }
    }

    private func keyValueRow(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private func linkButton(
        _ systemImage: String,
        _ label: String,
        _ urlString: String
    ) -> some View {
        Button {
            openURL(urlString)
        } label: {
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .help(label)
        .accessibilityLabel(label)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        Self.log.notice("about.open_url url=\(url.absoluteString, privacy: .public)")
        NSWorkspace.shared.open(url)
    }

    private var isUpdaterConfigured: Bool {
        updaterModel?.isConfigured ?? false
    }

    private var updateStatusLabel: String {
        guard let updaterModel, updaterModel.canCheckForUpdates else {
            return "Updater is starting"
        }
        return "Automatic updates are on"
    }

    private var automaticChecksBinding: Binding<Bool> {
        Binding(
            get: { updaterModel?.automaticallyChecksForUpdates ?? false },
            set: { updaterModel?.setAutomaticallyChecksForUpdates($0) }
        )
    }
}
