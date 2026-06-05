//
//  EnvironmentValues+Models.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesDomain
import SwiftUI

// The App composition root constructs the concrete models and services once and
// sets these keys. Features read them through `@Environment(\.…)` and never see
// a concrete type. Model keys default to nil because the models have no
// dependency-free initializer; a view that reads one runs only after the App
// has populated it.
extension EnvironmentValues {
    @Entry public var noteWorkspaceModel: NoteWorkspaceModel?
    @Entry public var noteWindowStateModel: NoteWindowStateModel?
    @Entry public var updaterModel: UpdaterModel?
    @Entry public var runtimeInfo: any RuntimeInfoProviding = Self.placeholderRuntimeInfo()

    // The default flows through this helper so the extension carries mixed
    // access levels, which keeps SwiftLint from asking us to hoist `public`
    // onto the extension keyword.
    private static func placeholderRuntimeInfo() -> any RuntimeInfoProviding {
        PlaceholderRuntimeInfo()
    }
}
