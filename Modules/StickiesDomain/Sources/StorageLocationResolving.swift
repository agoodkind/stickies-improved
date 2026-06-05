//
//  StorageLocationResolving.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

/// Resolves the on-disk root that holds the note packages, abstracting the
/// iCloud-versus-local choice out of the store so the store stays testable.
public protocol StorageLocationResolving: Sendable {
    func resolveLibraryURL() throws -> URL
}
