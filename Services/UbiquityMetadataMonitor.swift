//
//  UbiquityMetadataMonitor.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

@preconcurrency
@MainActor
public final class UbiquityMetadataMonitor: NSObject {
    public var onLibraryDidChange: (() -> Void)?

    private let query = NSMetadataQuery()
    private var didConfigure = false

    public func startMonitoring(rootURL _: URL) {
        guard !didConfigure else { return }
        didConfigure = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQueryUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleQueryUpdate),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )

        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*.stickynote'", NSMetadataItemFSNameKey)
        query.start()
    }

    @objc private func handleQueryUpdate() {
        onLibraryDidChange?()
    }
}
