//
//  FocusedValues+NoteID.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesDomain
import SwiftUI

// Published by the focused note scene and read by the Colour menu so menu
// actions target the note window the user is currently working in.
public struct FocusedNoteIDKey: FocusedValueKey {
    public typealias Value = NoteID
}

// MARK: - FocusedValues

extension FocusedValues {
    public var focusedNoteID: NoteID? {
        get { storedFocusedNoteID }
        set { storedFocusedNoteID = newValue }
    }

    // The private accessor backing the public property gives this extension mixed
    // access levels, which is what stops SwiftLint asking us to hoist `public`
    // onto the extension keyword (the same trick as EnvironmentValues+Models).
    private var storedFocusedNoteID: NoteID? {
        get { self[FocusedNoteIDKey.self] }
        set { self[FocusedNoteIDKey.self] = newValue }
    }
}
