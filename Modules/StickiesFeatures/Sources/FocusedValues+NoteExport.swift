//
//  FocusedValues+NoteExport.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import SwiftUI

// Published by the focused note's editor host as a binding to its own
// `.fileExporter` presentation flag, so the File-menu "Export..." command can
// trigger the exporter on whichever note window is focused. The binding is nil
// when no note is focused, which also drives the command's disabled state.
public struct NoteExportTriggerKey: FocusedValueKey {
    public typealias Value = Binding<Bool>
}

// MARK: - FocusedValues

extension FocusedValues {
    public var noteExportTrigger: Binding<Bool>? {
        get { storedNoteExportTrigger }
        set { storedNoteExportTrigger = newValue }
    }

    // The private accessor backing the public property gives this extension mixed
    // access levels, which stops SwiftLint asking us to hoist `public` onto the
    // extension keyword (the same trick as FocusedValues+NoteID).
    private var storedNoteExportTrigger: Binding<Bool>? {
        get { self[NoteExportTriggerKey.self] }
        set { self[NoteExportTriggerKey.self] = newValue }
    }
}
