import AppKit
import SwiftUI

struct StickyWindowChromeBridge: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindowIfNeeded(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async {
            configureWindowIfNeeded(from: nsView)
        }
    }

    @MainActor
    private func configureWindowIfNeeded(from view: NSView) {
        guard let window = view.window else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
    }
}
