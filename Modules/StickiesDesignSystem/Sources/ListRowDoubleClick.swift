//
//  ListRowDoubleClick.swift
//  StickiesImproved
//
//  Created by Alexander Goodkind <alex@goodkind.io> on 25/04/2026.
//  Copyright © 2026, all rights reserved.
//

import AppKit
import SwiftUI

/// Installs a double-click handler on the AppKit table backing an enclosing SwiftUI
/// `List`. Drop it into the list's `.background`. The recognizer attaches once, off the
/// SwiftUI render path, so rows carry no per-render gesture state. Single clicks still
/// drive the list's native selection because the recognizer only fires on the second
/// click; the first click selects the row and the second invokes `action`.
public struct ListRowDoubleClick: NSViewRepresentable {
    private let action: () -> Void

    public init(perform action: @escaping () -> Void) {
        self.action = action
    }

    public func makeNSView(context: Context) -> NSView {
        let anchor = NSView(frame: .zero)
        let coordinator = context.coordinator
        coordinator.anchor = anchor
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                coordinator.installIfNeeded()
            }
        }
        return anchor
    }

    public func updateNSView(_: NSView, context: Context) {
        let coordinator = context.coordinator
        coordinator.action = action
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                coordinator.installIfNeeded()
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    @preconcurrency
    @MainActor
    public final class Coordinator: NSObject {
        private enum Click {
            static let doubleClick = 2
        }

        var action: () -> Void
        weak var anchor: NSView?
        private weak var installedTarget: NSView?

        init(action: @escaping () -> Void) {
            self.action = action
        }

        /// Walks from the anchor to the table backing the enclosing list and attaches
        /// the double-click recognizer a single time. Retried from `updateNSView`
        /// because the scroll view may not be in the hierarchy on first layout.
        func installIfNeeded() {
            guard installedTarget == nil, let anchor else {
                return
            }
            guard let target = Self.backingTable(from: anchor) else {
                return
            }
            let recognizer = NSClickGestureRecognizer(
                target: self,
                action: #selector(handleDoubleClick)
            )
            recognizer.numberOfClicksRequired = Click.doubleClick
            recognizer.delaysPrimaryMouseButtonEvents = false
            target.addGestureRecognizer(recognizer)
            installedTarget = target
        }

        private static func backingTable(from view: NSView) -> NSView? {
            if let documentView = view.enclosingScrollView?.documentView {
                return documentView
            }
            guard let contentView = view.window?.contentView else {
                return nil
            }
            return firstScrollDocument(in: contentView)
        }

        private static func firstScrollDocument(in view: NSView) -> NSView? {
            if let scrollView = view as? NSScrollView, let documentView = scrollView.documentView {
                return documentView
            }
            for subview in view.subviews {
                if let found = firstScrollDocument(in: subview) {
                    return found
                }
            }
            return nil
        }

        @objc private func handleDoubleClick() {
            action()
        }
    }
}
