//
//  NoteColor.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

/// sRGB channel values for a note color, alpha is always 1. A named struct
/// rather than a 3-member tuple so the `large_tuple` lint rule stays satisfied
/// while `.components.red` style access is preserved.
public struct RGBComponents: Equatable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double

  public init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }
}

// MARK: - NoteColor

public enum NoteColor: String, CaseIterable, Codable, Sendable {
  case blue
  case brown
  case gray
  case green
  case orange
  case pink
  case purple
  case red
  case white
  case yellow

  /// The default new-note color, recovered from the original
  /// `-[StickieBackgroundView getYellowColour]`.
  public static let `default`: NoteColor = .yellow

  public var components: RGBComponents {
    switch self {
    case .yellow:
      let red = 0.98
      let green = 0.90
      let blue = 0.45
      return RGBComponents(red: red, green: green, blue: blue)
    case .blue:
      let red = 0.53
      let green = 0.83
      let blue = 0.96
      return RGBComponents(red: red, green: green, blue: blue)
    case .brown:
      let red = 0.87
      let green = 0.69
      let blue = 0.48
      return RGBComponents(red: red, green: green, blue: blue)
    case .gray:
      let red = 0.50
      let green = 0.50
      let blue = 0.50
      return RGBComponents(red: red, green: green, blue: blue)
    case .green:
      let red = 0.68
      let green = 0.83
      let blue = 0.47
      return RGBComponents(red: red, green: green, blue: blue)
    case .orange:
      let red = 0.95
      let green = 0.65
      let blue = 0.24
      return RGBComponents(red: red, green: green, blue: blue)
    case .pink:
      let red = 0.96
      let green = 0.62
      let blue = 0.84
      return RGBComponents(red: red, green: green, blue: blue)
    case .purple:
      let red = 0.69
      let green = 0.49
      let blue = 0.77
      return RGBComponents(red: red, green: green, blue: blue)
    case .red:
      let red = 0.92
      let green = 0.34
      let blue = 0.30
      return RGBComponents(red: red, green: green, blue: blue)
    case .white:
      let red = 1.0
      let green = 1.0
      let blue = 1.0
      return RGBComponents(red: red, green: green, blue: blue)
    }
  }

  /// Muted, low-luminance variant of each color for the note background under the dark
  /// system appearance, so a note is legible against a dark desktop instead of glaring.
  /// The hue is preserved while the brightness drops and light text sits on top. The
  /// bright `components` value is still used for the small swatches in list UI.
  public var darkComponents: RGBComponents {
    switch self {
    case .yellow:
      let red = 0.30
      let green = 0.26
      let blue = 0.13
      return RGBComponents(red: red, green: green, blue: blue)
    case .blue:
      let red = 0.16
      let green = 0.24
      let blue = 0.34
      return RGBComponents(red: red, green: green, blue: blue)
    case .brown:
      let red = 0.30
      let green = 0.23
      let blue = 0.15
      return RGBComponents(red: red, green: green, blue: blue)
    case .gray:
      let red = 0.24
      let green = 0.24
      let blue = 0.26
      return RGBComponents(red: red, green: green, blue: blue)
    case .green:
      let red = 0.18
      let green = 0.30
      let blue = 0.18
      return RGBComponents(red: red, green: green, blue: blue)
    case .orange:
      let red = 0.34
      let green = 0.22
      let blue = 0.11
      return RGBComponents(red: red, green: green, blue: blue)
    case .pink:
      let red = 0.34
      let green = 0.20
      let blue = 0.28
      return RGBComponents(red: red, green: green, blue: blue)
    case .purple:
      let red = 0.26
      let green = 0.20
      let blue = 0.34
      return RGBComponents(red: red, green: green, blue: blue)
    case .red:
      let red = 0.36
      let green = 0.16
      let blue = 0.16
      return RGBComponents(red: red, green: green, blue: blue)
    case .white:
      let red = 0.20
      let green = 0.20
      let blue = 0.22
      return RGBComponents(red: red, green: green, blue: blue)
    }
  }
}
