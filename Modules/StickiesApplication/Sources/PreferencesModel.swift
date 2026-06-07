//
//  PreferencesModel.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import Foundation
import Observation
import StickiesDomain

/// Holds the user-facing app preferences, backed by an injected `UserDefaults`
/// so the values survive launches and the model stays testable against an
/// in-memory suite. Each setter writes through immediately, so the window bridge
/// and resolver that read the same keys observe the change on their next read.
@preconcurrency
@MainActor
@Observable
public final class PreferencesModel {
  public enum Bounds {
    public static let minimumTransparency = 0.5
    public static let maximumTransparency = 1.0
    public static let minimumVerbosity = 0
    public static let maximumVerbosity = 3
  }

  private enum Key {
    // Matches the key StickyWindowChromeBridge reads for the unfocused alpha.
    static let unfocusedTransparency = "nonFocusTransparency"
    static let defaultColor = "defaultNoteColor"
    static let verbosity = "logVerbosity"
  }

  private enum Fallback {
    static let unfocusedTransparency = 0.97
    static let verbosity = 1
  }

  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public var storageMode: StorageMode {
    get {
      guard let raw = defaults.string(forKey: StorageMode.defaultsKey),
        let mode = StorageMode(rawValue: raw)
      else {
        return .default
      }
      return mode
    }
    set {
      defaults.set(newValue.rawValue, forKey: StorageMode.defaultsKey)
    }
  }

  public var unfocusedTransparency: Double {
    get {
      guard defaults.object(forKey: Key.unfocusedTransparency) != nil else {
        return Fallback.unfocusedTransparency
      }
      let stored = defaults.double(forKey: Key.unfocusedTransparency)
      return min(max(stored, Bounds.minimumTransparency), Bounds.maximumTransparency)
    }
    set {
      let clamped = min(max(newValue, Bounds.minimumTransparency), Bounds.maximumTransparency)
      defaults.set(clamped, forKey: Key.unfocusedTransparency)
    }
  }

  public var defaultColor: NoteColor {
    get {
      guard let raw = defaults.string(forKey: Key.defaultColor),
        let color = NoteColor(rawValue: raw)
      else {
        return .default
      }
      return color
    }
    set {
      defaults.set(newValue.rawValue, forKey: Key.defaultColor)
    }
  }

  public var verbosity: Int {
    get {
      guard defaults.object(forKey: Key.verbosity) != nil else {
        return Fallback.verbosity
      }
      let stored = defaults.integer(forKey: Key.verbosity)
      return min(max(stored, Bounds.minimumVerbosity), Bounds.maximumVerbosity)
    }
    set {
      let clamped = min(max(newValue, Bounds.minimumVerbosity), Bounds.maximumVerbosity)
      defaults.set(clamped, forKey: Key.verbosity)
    }
  }
}
