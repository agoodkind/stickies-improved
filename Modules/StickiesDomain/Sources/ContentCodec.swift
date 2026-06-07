//
//  ContentCodec.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

/// The persistence-boundary seam for note content. The identity implementation
/// in Persistence passes UTF-8 through unchanged, leaving room for real
/// encryption to drop in here later.
public protocol ContentCodec: Sendable {
  func encode(_ text: String) throws -> Data
  func decode(_ data: Data) throws -> String
}
