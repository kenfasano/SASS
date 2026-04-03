import AppKit
import SwiftUI

class ScreenWindow: NSWindow {
    private var hostingView: NSHostingView<SlideshowView>?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenPrimary, .stationary]
        self.backgroundColor = .black
        self.isOpaque = true
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = false
        self.isReleasedWhenClosed = false

        let view = SlideshowView()
        let hosting = NSHostingView(rootView: view)
        hosting.frame = screen.frame
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting
        self.hostingView = hosting

        // Cover the full screen including menu bar
        setFrame(screen.frame, display: true)
    }

    // Quit on any key press
    override func keyDown(with event: NSEvent) {
        NSApp.terminate(nil)
    }

    // Quit on mouse click
    override func mouseDown(with event: NSEvent) {
        NSApp.terminate(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
