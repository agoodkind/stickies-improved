import StickiesImprovedCore
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Stickies Improved")
                .font(.title)
            Text("Plain-text notes with iCloud sync.")
                .foregroundStyle(.secondary)
            Text("Version \(BuildConfig.marketingVersion) (\(BuildConfig.buildVersion))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 280)
    }
}
