//
//  NoteStore.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation

public protocol NoteStore: Sendable {
  func ensureLibraryDirectory() async throws -> URL
  func loadAllDocuments() async throws -> [NoteDocument]
  func loadDocument(id: NoteID) async throws -> NoteDocument
  func save(_ document: NoteDocument) async throws
  func delete(id: NoteID) async throws
}
