//
//  HexColor.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import SwiftUI

/// Bridges a SwiftUI `Color` to and from a `"#RRGGBB"` hex string so the per-note text
/// color can round-trip through `NoteMetadata.fontColorHex`, which is a plain `String?`.
/// Storing a hex string keeps the persisted form human-readable and codec-agnostic while
/// still reproducing one uniform text color per note.
public enum HexColor {
  private static let hexPrefix = "#"
  private static let channelMax = 255.0
  private static let expectedHexLength = 6
  private static let hexRadix = 16
  private static let byteMask = 0xFF
  private static let redShift = 16
  private static let greenShift = 8

  /// Serializes a color to `"#RRGGBB"` by resolving it in the sRGB space. The resolve
  /// pass flattens any dynamic color into concrete sRGB components, so a user-picked
  /// color always round-trips to a stable hex string.
  public static func string(from color: Color) -> String? {
    let resolved = color.resolve(in: EnvironmentValues())
    let red = Int((Double(resolved.red) * channelMax).rounded())
    let green = Int((Double(resolved.green) * channelMax).rounded())
    let blue = Int((Double(resolved.blue) * channelMax).rounded())
    return String(format: "\(hexPrefix)%02X%02X%02X", red, green, blue)
  }

  /// Parses a `"#RRGGBB"` string back into an sRGB `Color`. Returns `nil` for any
  /// malformed input so the caller can substitute the default text color.
  public static func color(from hex: String) -> Color? {
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
    return Color(
      .sRGB,
      red: redByte / channelMax,
      green: greenByte / channelMax,
      blue: blueByte / channelMax,
      opacity: 1.0
    )
  }
}
