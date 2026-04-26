import StickiesImprovedCore
import SwiftUI

struct SettingsView: View {
    @Environment(NoteWorkspaceStore.self) private var workspace
    @Environment(AppUpdater.self) private var appUpdater

    var body: some View {
        Form {
            Section("Storage") {
                LabeledContent("Bundle ID", value: BuildConfig.appBundleID)
                LabeledContent("iCloud Container", value: BuildConfig.iCloudContainerIdentifier)
                LabeledContent("Current Root", value: workspace.storageLocationDescription)
            }

            Section("Editor") {
                LabeledContent("Enabled Mode", value: "Plain Text")
                LabeledContent("Future Mode", value: "Markdown (not yet implemented)")
            }

            Section("Updates") {
                LabeledContent("Feed URL", value: BuildConfig.sparkleFeedURL)
                Button("Check for Updates") {
                    appUpdater.checkForUpdates()
                }
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
