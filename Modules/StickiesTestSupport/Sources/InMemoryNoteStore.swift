//
//  InMemoryNoteStore.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import StickiesDomain

/// A dictionary-backed `NoteStore` for deterministic tests. The actor isolation
/// matches the real store so call sites read identically.
public actor InMemoryNoteStore: NoteStore {
  private var documents: [NoteID: NoteDocument] = [:]
  private let rootURL: URL

  public init(rootURL: URL = FileManager.default.temporaryDirectory) {
    self.rootURL = rootURL
  }

  public var savedCount: Int {
    documents.count
  }

  /// Non-throwing peek for tests that poll until a save lands.
  public func document(for id: NoteID) -> NoteDocument? {
    documents[id]
  }

  public func ensureLibraryDirectory() -> URL {
    rootURL
  }

  public func loadAllDocuments() -> [NoteDocument] {
    Array(documents.values)
  }

  public func loadDocument(id: NoteID) throws -> NoteDocument {
    guard let document = documents[id] else {
      throw CocoaError(.fileNoSuchFile)
    }
    return document
  }

  public func save(_ document: NoteDocument) {
    documents[document.id] = document
  }

  public func delete(id: NoteID) {
    documents[id] = nil
  }
}
