import AppKit
import SwiftUI

/// A floating NSPanel with Liquid Glass background.
/// Hosts SwiftUI content and supports keyboard input without activating the app.
final class FloatingPanel: NSPanel {

    init<Content: View>(@ViewBuilder content: () -> Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 420),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        hasShadow = true

        let hostingView = NSHostingView(rootView: content())
        hostingView.sizingOptions = .intrinsicContentSize

        contentView = hostingView
        contentMaxSize = NSSize(width: 320, height: 480)
    }

    override var canBecomeKey: Bool { true }
}
