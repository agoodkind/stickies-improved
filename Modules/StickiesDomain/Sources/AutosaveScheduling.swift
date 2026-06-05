//
//  AutosaveScheduling.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

public protocol AutosaveScheduling: Sendable {
    func sleep(for duration: Duration) async throws
}
