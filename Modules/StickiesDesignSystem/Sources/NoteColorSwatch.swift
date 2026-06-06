//
//  NoteColorSwatch.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import StickiesDomain
import SwiftUI

/// The small rounded color chip that marks a note's color in lists and previews. It
/// always draws the vivid swatch color so the note's color stays recognizable in both
/// appearances, with a hairline separator stroke so light swatches keep an edge.
public struct NoteColorSwatch: View {
    // Public so the values can serve as default arguments of the public initializer,
    // which Swift requires to be at least as accessible as the initializer itself.
    public enum Default {
        public static let size: CGFloat = 14
        public static let cornerRadius: CGFloat = 3
    }

    private let color: NoteColor
    private let size: CGFloat
    private let cornerRadius: CGFloat

    public init(
        _ color: NoteColor,
        size: CGFloat = Default.size,
        cornerRadius: CGFloat = Default.cornerRadius
    ) {
        self.color = color
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(color.swatchColor)
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.separator)
            )
    }
}
