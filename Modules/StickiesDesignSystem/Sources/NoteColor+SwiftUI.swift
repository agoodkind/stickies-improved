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
    /// The bright, vivid color for small swatches in list UI. It stays vivid in both
    /// light and dark appearance so a note's color is always recognizable in lists.
    public var swatchColor: Color {
        Self.swiftUIColor(from: components)
    }

    /// The note window background, which adapts to the appearance: the vivid pastel under
    /// the light scheme and the muted dark variant under the dark scheme.
    public func backgroundColor(for scheme: ColorScheme) -> Color {
        let rgb = scheme == .dark ? darkComponents : components
        return Self.swiftUIColor(from: rgb)
    }

    private static func swiftUIColor(from rgb: RGBComponents) -> Color {
        Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}
