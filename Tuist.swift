//
//  Tuist.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import ProjectDescription

let tuist = Tuist(
    project: .tuist(
        generationOptions: .options(
            disableSandbox: false,
            includeGenerateScheme: true
        )
    )
)
