//
//  HexColor.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit

/// Bridges an `NSColor` to and from a `"#RRGGBB"` hex string so the per-note text
/// color can round-trip through `NoteMetadata.fontColorHex`, which is a plain
/// `String?`. The original Plain Text Stickies archived an `NSColor`; storing a hex
/// string keeps the persisted form human-readable and codec-agnostic while still
/// reproducing one uniform text color per note.
public enum HexColor {
    private static let hexPrefix = "#"
    private static let channelMax = 255.0
    private static let expectedHexLength = 6
    private static let hexRadix = 16
    private static let byteMask = 0xFF
    private static let redShift = 16
    private static let greenShift = 8

    /// Serializes a color in the sRGB space to `"#RRGGBB"`. Returns `nil` when the
    /// color cannot be represented in sRGB (for example a pattern or catalog color),
    /// so the caller can fall back to the default text color rather than persist a
    /// meaningless value.
    public static func string(from color: NSColor) -> String? {
        guard let rgbColor = color.usingColorSpace(.sRGB) else {
            return nil
        }
        let red = Int((rgbColor.redComponent * channelMax).rounded())
        let green = Int((rgbColor.greenComponent * channelMax).rounded())
        let blue = Int((rgbColor.blueComponent * channelMax).rounded())
        return String(format: "\(hexPrefix)%02X%02X%02X", red, green, blue)
    }

    /// Parses a `"#RRGGBB"` string back into an sRGB `NSColor`. Returns `nil` for any
    /// malformed input so the caller can substitute `NSColor.textColor`.
    public static func color(from hex: String) -> NSColor? {
        var normalized = hex
        if normalized.hasPrefix(hexPrefix) {
            normalized.removeFirst()
        }
        guard normalized.count == expectedHexLength else {
            return nil
        }
        guard let value = Int(normalized, radix: hexRadix) else {
            return nil
        }

        let redByte = Double((value >> redShift) & byteMask)
        let greenByte = Double((value >> greenShift) & byteMask)
        let blueByte = Double(value & byteMask)
        return NSColor(
            srgbRed: redByte / channelMax,
            green: greenByte / channelMax,
            blue: blueByte / channelMax,
            alpha: 1.0
        )
    }
}
