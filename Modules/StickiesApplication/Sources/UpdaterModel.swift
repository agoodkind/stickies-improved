//
//  UpdaterModel.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Observation
import StickiesDomain

@preconcurrency
@Observable
@MainActor
public final class UpdaterModel {
    private let controller: any UpdaterControlling

    public init(controller: any UpdaterControlling) {
        self.controller = controller
    }

    public func checkForUpdates() {
        controller.checkForUpdates()
    }
}
