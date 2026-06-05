//
//  ContinuousClockAutosaveScheduler.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain

public struct ContinuousClockAutosaveScheduler: AutosaveScheduling {
    private let clock = ContinuousClock()

    public init() {
        // No state to configure.
    }

    public func sleep(for duration: Duration) async throws {
        try await clock.sleep(for: duration)
    }
}
