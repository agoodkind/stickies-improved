//
//  UbiquityLibraryMonitor.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain

@preconcurrency
@MainActor
public final class UbiquityLibraryMonitor: NSObject, LibraryMonitoring {
    private let query = NSMetadataQuery()
    private var didConfigure = false
    private var onChange: (() -> Void)?

    override public init() {
        super.init()
    }

    public func startMonitoring(rootURL _: URL, onChange: @escaping () -> Void) {
        guard !didConfigure else { return }
        didConfigure = true
        self.onChange = onChange

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
        onChange?()
    }
}
