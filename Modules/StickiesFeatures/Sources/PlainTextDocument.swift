//
//  PlainTextDocument.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// A minimal `FileDocument` wrapping a note's plain text so SwiftUI's
/// `.fileExporter` can write a `.txt` file. Export is one-directional, so reading
/// is implemented for protocol conformance but the app only ever writes.
public struct PlainTextDocument: FileDocument {
  public static let readableContentTypes: [UTType] = [.plainText]

  public var text: String

  public init(text: String) {
    self.text = text
  }

  public init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents,
      let decoded = String(bytes: data, encoding: .utf8)
    else {
      throw CocoaError(.fileReadCorruptFile)
    }
    text = decoded
  }

  public func fileWrapper(configuration _: WriteConfiguration) -> FileWrapper {
    let data = Data(text.utf8)
    return FileWrapper(regularFileWithContents: data)
  }
}
