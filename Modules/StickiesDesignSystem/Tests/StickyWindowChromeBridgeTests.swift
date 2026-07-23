//
//  StickyWindowChromeBridgeTests.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 04/07/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
import Testing

@testable import StickiesDesignSystem

// MARK: - StickyWindowChromeBridgeTests

@MainActor
struct StickyWindowChromeBridgeTests {
  @Test func collapseShrinksWindowToCollapsedHeightAndShowsTitle() {
    let coordinator = StickyWindowChromeBridge.Coordinator()
    let window = makeWindow(height: 400)
    coordinator.window = window
    coordinator.collapsedTitle = { "Collapsed Title" }

    coordinator.collapse(window: window, animate: false)

    #expect(window.frame.height == StickyWindowChromeBridge.Fold.collapsedHeight)
    #expect(window.title == StickyWindowChromeBridge.Fold.titlePrefix + "Collapsed Title")
    #expect(window.titleVisibility == .visible)
    #expect(coordinator.isCollapsed)
    #expect(coordinator.expandedHeight == 400)
    #expect(window.contentMinSize.height == StickyWindowChromeBridge.Fold.collapsedHeight)
    #expect(window.minSize.height == StickyWindowChromeBridge.Fold.collapsedHeight)
  }

  @Test func expandRestoresHeightAndHidesTitle() {
    let coordinator = StickyWindowChromeBridge.Coordinator()
    let window = makeWindow(height: 400)
    coordinator.window = window
    coordinator.collapsedTitle = { "Collapsed Title" }

    coordinator.collapse(window: window, animate: false)
    coordinator.expand(window: window, animate: false)

    #expect(window.frame.height == 400)
    #expect(window.titleVisibility == .hidden)
    #expect(coordinator.isCollapsed == false)
  }

  @Test func applyCollapsedFrameUsesCollapsedHeightWithoutChangingExpandedHeight() {
    let coordinator = StickyWindowChromeBridge.Coordinator()
    let window = makeWindow(height: 480)
    coordinator.window = window
    coordinator.collapsedTitle = { "Saved Title" }
    coordinator.expandedHeight = 512
    coordinator.isCollapsed = true

    coordinator.applyCollapsedFrame(animate: false)

    #expect(window.frame.height == StickyWindowChromeBridge.Fold.collapsedHeight)
    #expect(window.title == StickyWindowChromeBridge.Fold.titlePrefix + "Saved Title")
    #expect(window.titleVisibility == .visible)
    #expect(coordinator.expandedHeight == 512)
  }

  private func makeWindow(height: CGFloat) -> NSPanel {
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 400, height: height),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.setFrame(
      NSRect(x: 0, y: 0, width: 400, height: height),
      display: false
    )
    return panel
  }
}
