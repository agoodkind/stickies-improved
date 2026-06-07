//
//  NoteWindowStateModel.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Observation
import StickiesDomain

@preconcurrency
@Observable
@MainActor
public final class NoteWindowStateModel {
  private let defaults: UserDefaults
  private let openNoteIDsKey = "open-note-ids"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public var openNoteIDs: [NoteID] {
    let values = defaults.stringArray(forKey: openNoteIDsKey) ?? []
    return values.compactMap(NoteID.init)
  }

  public func noteWindowOpened(_ noteID: NoteID) {
    var ids = Set(openNoteIDs)
    ids.insert(noteID)
    persist(ids)
  }

  public func noteWindowClosed(_ noteID: NoteID) {
    var ids = Set(openNoteIDs)
    ids.remove(noteID)
    persist(ids)
  }

  private func persist(_ ids: Set<NoteID>) {
    defaults.set(ids.map(\.description).sorted(), forKey: openNoteIDsKey)
  }
}
