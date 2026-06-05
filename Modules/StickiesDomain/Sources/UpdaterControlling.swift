//
//  UpdaterControlling.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

@preconcurrency
@MainActor
public protocol UpdaterControlling {
    func checkForUpdates()
}
