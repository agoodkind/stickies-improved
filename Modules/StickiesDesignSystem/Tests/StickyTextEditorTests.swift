//
//  StickyTextEditorTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 04/07/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
import Testing

@testable import StickiesDesignSystem

private enum StickyTextEditorTestError: Error {
  case missingDeleteEvent
}

// MARK: - StickyTextEditorTests

@MainActor
struct StickyTextEditorTests {
  @Test func commandDeleteTriggersHandlerAndLeavesTextUnchanged() throws {
    var callCount = 0
    let textView = StickyCommandTextView()
    textView.onCommandDelete = { callCount += 1 }
    textView.string = "first line\nsecond line"
    textView.setSelectedRange(NSRange(location: 8, length: 0))

    textView.keyDown(with: try deleteEvent(modifierFlags: [.command]))

    #expect(callCount == 1)
    #expect(textView.string == "first line\nsecond line")
  }

  @Test func commandBackspaceTriggersHandlerAndLeavesTextUnchanged() throws {
    var callCount = 0
    let textView = StickyCommandTextView()
    textView.onCommandDelete = { callCount += 1 }
    textView.string = "first line\nsecond line"
    textView.setSelectedRange(NSRange(location: 8, length: 0))

    textView.keyDown(
      with: try deleteEvent(
        modifierFlags: [.command],
        characters: "\u{8}"
      )
    )

    #expect(callCount == 1)
    #expect(textView.string == "first line\nsecond line")
  }

  @Test func plainDeleteDoesNotTriggerHandler() throws {
    var callCount = 0
    let textView = StickyCommandTextView()
    textView.onCommandDelete = { callCount += 1 }
    textView.string = "ab"
    textView.setSelectedRange(NSRange(location: 1, length: 0))

    textView.keyDown(with: try deleteEvent())

    #expect(callCount == 0)
  }

  @Test func performKeyEquivalentTriggersHandler() throws {
    var callCount = 0
    let textView = StickyCommandTextView()
    textView.onCommandDelete = { callCount += 1 }
    textView.string = "first line\nsecond line"

    let handled = textView.performKeyEquivalent(
      with: try deleteEvent(modifierFlags: [.command], characters: "\u{8}")
    )

    #expect(handled)
    #expect(callCount == 1)
    #expect(textView.string == "first line\nsecond line")
  }

  @Test func optionCommandDeleteDoesNotTriggerHandler() throws {
    var callCount = 0
    let textView = StickyCommandTextView()
    textView.onCommandDelete = { callCount += 1 }
    textView.string = "alpha beta"
    textView.setSelectedRange(NSRange(location: 10, length: 0))

    textView.keyDown(with: try deleteEvent(modifierFlags: [.command, .option]))

    #expect(callCount == 0)
  }

  private func deleteEvent(
    modifierFlags: NSEvent.ModifierFlags = [],
    characters: String = "\u{7F}"
  ) throws -> NSEvent {
    guard
      let event = NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: modifierFlags,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: 51
      )
    else {
      throw StickyTextEditorTestError.missingDeleteEvent
    }
    return event
  }
}
