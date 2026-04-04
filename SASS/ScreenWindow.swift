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

        setFrame(screen.frame, display: true)
    }

    override func keyDown(with event: NSEvent) {
        let cmd  = event.modifierFlags.contains(.command)
        let char = event.charactersIgnoringModifiers ?? ""
        sassLog("keyDown char='\(char)' cmd=\(cmd) keyCode=\(event.keyCode)")

        if cmd {
            if char == "," {
                sassLog("cmd-, detected — calling show()")
                ConfigurationWindowController.shared.show()
                return
            }
            if NSApp.mainMenu?.performKeyEquivalent(with: event) == true {
                return
            }
        }

        // Any plain key (or unhandled combo) → quit
        NSApp.terminate(nil)
    }

    override func mouseDown(with event: NSEvent) {
        NSApp.terminate(nil)
    }

    override var canBecomeKey:  Bool { !ignoresMouseEvents }
    override var canBecomeMain: Bool { !ignoresMouseEvents }
}
