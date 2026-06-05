//
//  NoteColor+SwiftUI.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesDomain
import SwiftUI

extension NoteColor {
    public var color: Color {
        Self.swiftUIColor(from: components)
    }

    private static func swiftUIColor(from rgb: RGBComponents) -> Color {
        Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
