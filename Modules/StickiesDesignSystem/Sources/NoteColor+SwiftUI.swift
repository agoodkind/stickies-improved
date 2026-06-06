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

    /// A filled color circle rendered as an image for use as a menu item icon. A plain
    /// `Image(systemName:).foregroundStyle(...)` renders monochrome in an `NSMenu`, which
    /// strips the color; rasterizing the circle and forcing the original rendering mode
    /// keeps the real color in menus.
    @preconcurrency
    @MainActor
    public func swatchImage() -> Image {
        // Rasterize each color once and cache it: menus and pickers ask for these on
        // every render, and `ImageRenderer` is a synchronous main-thread rasterization
        // that would otherwise run per color per render.
        if let cached = Self.swatchImageCache[self] {
            return cached
        }
        let renderer = ImageRenderer(
            content: Circle()
                .fill(swatchColor)
                .frame(width: Swatch.side, height: Swatch.side)
        )
        renderer.scale = Swatch.scale
        let image: Image
        if let cgImage = renderer.cgImage {
            image = Image(decorative: cgImage, scale: Swatch.scale).renderingMode(.original)
        } else {
            image = Image(systemName: "circle.fill")
        }
        Self.swatchImageCache[self] = image
        return image
    }

    @MainActor private static var swatchImageCache: [NoteColor: Image] = [:]

    private enum Swatch {
        static let side: CGFloat = 11
        static let scale: CGFloat = 2
    }
}
