//
//  ActivityPublishing.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

/// A seam for surfacing the active note through Handoff later. The current
/// implementation is a no-op so the wiring exists without a behavior change.
public protocol ActivityPublishing: Sendable {
    func publish(noteID: NoteID, title: String)
}

// MARK: - NoopActivityPublisher

public struct NoopActivityPublisher: ActivityPublishing {
    public init() {
        // No state to configure.
    }

    public func publish(noteID _: NoteID, title _: String) {
        // Intentionally does nothing until Handoff lands.
    }
}
