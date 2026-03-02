import AppKit
import SwiftUI

/// A floating NSPanel that stays above other windows.
/// Hosts SwiftUI content and supports keyboard input without activating the app.
final class FloatingPanel: NSPanel {

    init<Content: View>(@ViewBuilder content: () -> Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
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

        contentView = NSHostingView(rootView: content())
    }

    override var canBecomeKey: Bool { true }
}
