//
//  ColorPickerMenuItems.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesApplication
import StickiesDesignSystem
import StickiesDomain
import SwiftUI

// One labeled, swatch-tinted button per palette color. Shared by the Colour
// command menu and the in-window right-click context menu so both lists stay
// in sync with `NoteColor.allCases`.
struct ColorPickerMenuItems: View {
  @Environment(\.noteWorkspaceModel) private var workspace

  let noteID: NoteID

  var body: some View {
    ForEach(NoteColor.allCases, id: \.self) { color in
      Button {
        workspace?.updateColor(color, for: noteID)
      } label: {
        Label {
          Text(color.rawValue.capitalized)
        } icon: {
          color.swatchImage()
        }
      }
    }
  }
}
