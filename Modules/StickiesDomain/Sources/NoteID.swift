//
//  NoteID.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

public struct NoteID: Hashable, Codable, Identifiable, LosslessStringConvertible, Sendable {
  public let rawValue: UUID

  public init() {
    rawValue = UUID()
  }

  public init?(_ description: String) {
    guard let uuid = UUID(uuidString: description) else {
      return nil
    }
    rawValue = uuid
  }

  public var description: String {
    rawValue.uuidString.lowercased()
  }

  public var id: UUID {
    rawValue
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    guard let noteID = NoteID(value) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid note identifier: \(value)"
      )
    }
    self = noteID
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }
}
