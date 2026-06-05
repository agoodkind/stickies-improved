//
//  AboutView.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesImprovedCore
import SwiftUI

struct AboutView: View {
    private enum Layout {
        static let contentSpacing: CGFloat = 12
        static let contentPadding: CGFloat = 24
        static let windowWidth: CGFloat = 280
    }

    var body: some View {
        VStack(spacing: Layout.contentSpacing) {
            Text("Stickies Improved")
                .font(.title)
            Text("Plain-text notes with iCloud sync.")
                .foregroundStyle(.secondary)
            Text("Version \(BuildConfig.marketingVersion) (\(BuildConfig.buildVersion))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Layout.contentPadding)
        .frame(width: Layout.windowWidth)
    }
}
