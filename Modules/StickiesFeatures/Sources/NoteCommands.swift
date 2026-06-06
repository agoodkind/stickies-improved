//
//  NoteCommands.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import CoreText
import StickiesApplication
import StickiesDesignSystem
import StickiesDomain
import SwiftUI

public struct NoteCommands: Commands {
    private static let colorSwatchSymbol = "circle.fill"
    private static let managerWindowID = "manager"
    private static let systemFontLabel = "System Font"

    // The installed font families, read once with CoreText so the family Picker can pin a
    // font face without opening a system Fonts panel.
    private static let fontFamilies: [String] =
        (CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []).sorted()

    // Size bounds for the Bigger/Smaller commands, matching a sane editing range; the
    // original defaults to the system font at size 12.
    private enum FontSize {
        static let step: Double = 1
        static let minimum: Double = 8
        static let maximum: Double = 96
    }

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @FocusedValue(\.focusedNoteID) private var focusedNoteID
    @FocusedValue(\.noteExportTrigger) private var exportTrigger

    private let workspace: NoteWorkspaceModel
    private let updaterModel: UpdaterModel
    private let preferences: PreferencesModel

    public init(
        workspace: NoteWorkspaceModel,
        updaterModel: UpdaterModel,
        preferences: PreferencesModel
    ) {
        self.workspace = workspace
        self.updaterModel = updaterModel
        self.preferences = preferences
    }

    public var body: some Commands {
        // Replace the standard Save item so "Export..." sits in the File menu
        // where a save command would, exporting the focused note's plain text.
        CommandGroup(replacing: .saveItem) {
            Button("Export...") {
                exportTrigger?.wrappedValue = true
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(exportTrigger == nil)
        }

        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                let color = preferences.defaultColor
                Task {
                    let noteID = await workspace.createNote(color: color)
                    openWindow(value: noteID)
                }
            }
            .keyboardShortcut("n")

            Button("Delete Note") {
                if let focusedNoteID {
                    dismissWindow(value: focusedNoteID)
                    workspace.trashNote(focusedNoteID)
                }
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(focusedNoteID == nil)
        }

        CommandGroup(after: .appInfo) {
            Button("Check for Updates...") {
                updaterModel.checkForUpdates()
            }
        }

        // Add to the system Window menu so "Show All Notes" sits next to the
        // standard window list, opening the manager scene.
        CommandGroup(after: .windowList) {
            Button("Show All Notes") {
                openWindow(id: Self.managerWindowID)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }

        CommandMenu("Colour") {
            ForEach(NoteColor.allCases, id: \.self) { color in
                Button {
                    if let focusedNoteID {
                        workspace.updateColor(color, for: focusedNoteID)
                    }
                } label: {
                    Label {
                        Text(color.rawValue.capitalized)
                    } icon: {
                        Image(systemName: Self.colorSwatchSymbol)
                            .foregroundStyle(color.swatchColor)
                    }
                }
                .disabled(focusedNoteID == nil)
            }
        }

        CommandMenu("Format") {
            if let focusedNoteID, let note = workspace.note(for: focusedNoteID) {
                ColorPicker(
                    "Text Color",
                    selection: textColorBinding(for: focusedNoteID, metadata: note.metadata),
                    supportsOpacity: false
                )

                Picker(
                    "Font",
                    selection: fontFamilyBinding(for: focusedNoteID, metadata: note.metadata)
                ) {
                    Text(Self.systemFontLabel).tag(String?.none)
                    Divider()
                    ForEach(Self.fontFamilies, id: \.self) { family in
                        Text(family).tag(String?.some(family))
                    }
                }

                Divider()

                Button("Bigger") {
                    adjustFocusedFontSize(by: FontSize.step)
                }
                .keyboardShortcut("+")

                Button("Smaller") {
                    adjustFocusedFontSize(by: -FontSize.step)
                }
                .keyboardShortcut("-")
            }
        }
    }

    /// Binds the focused note's text color to a native `ColorPicker`. The getter shows the
    /// stored color or the default label color, while the setter persists only the color
    /// the user actually picks. The default stays `nil` rather than being written as an
    /// explicit color, which is what avoids the prior white-default persistence bug.
    private func textColorBinding(
        for noteID: NoteID,
        metadata: NoteMetadata
    ) -> Binding<Color> {
        Binding(
            get: {
                guard
                    let hex = metadata.fontColorHex,
                    let color = HexColor.color(from: hex)
                else {
                    return .primary
                }
                return color
            },
            set: { newColor in
                workspace.updateFontColor(hex: HexColor.string(from: newColor), for: noteID)
            }
        )
    }

    /// Binds the focused note's font family to a native `Picker`. A `nil` selection is the
    /// system font, so the note keeps tracking the system face rather than pinning a
    /// concrete name. The size is carried through unchanged.
    private func fontFamilyBinding(
        for noteID: NoteID,
        metadata: NoteMetadata
    ) -> Binding<String?> {
        Binding(
            get: { metadata.fontName },
            set: { newName in
                workspace.updateFont(name: newName, size: metadata.fontSize, for: noteID)
            }
        )
    }

    private func adjustFocusedFontSize(by delta: Double) {
        guard let focusedNoteID, let note = workspace.note(for: focusedNoteID) else { return }
        let currentSize = note.metadata.fontSize
        let proposedSize = currentSize + delta
        let clampedSize = min(max(proposedSize, FontSize.minimum), FontSize.maximum)
        guard clampedSize != currentSize else { return }
        workspace.updateFont(
            name: note.metadata.fontName,
            size: clampedSize,
            for: focusedNoteID
        )
    }
}
