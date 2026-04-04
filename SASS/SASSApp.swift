import SwiftUI
import AppKit
import IOKit.pwr_mgt

@main
struct SASSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var screenWindows: [ScreenWindow] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        AppDelegate.shared = self
        setupMenuBar()
        openWindowsForAllScreens()
        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitors()

        var assertionID: IOPMAssertionID = 0
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "SASS slideshow" as CFString,
            &assertionID
        )
    }

    // MARK: - Global + local key monitors

    private func installKeyMonitors() {
        // Global monitor catches events even when another app is key
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            self.handleKeyEvent(event)
        }
        // Local monitor catches events when our app is key
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.handleKeyEvent(event) {
                return nil  // consume the event
            }
            return event    // pass it through
        }
    }

    /// Returns true if the event was handled (consumed).
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let cmd  = event.modifierFlags.contains(.command)
        let char = event.charactersIgnoringModifiers ?? ""
        sassLog("handleKeyEvent char='\(char)' cmd=\(cmd)")

        if cmd && char == "," {
            sassLog("cmd-, matched — opening preferences")
            DispatchQueue.main.async {
                ConfigurationWindowController.shared.show()
            }
            return true
        }
        return false
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "About SASS",
                        action: #selector(NSApp.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.keyEquivalentModifierMask = .command
        prefsItem.target = self
        appMenu.addItem(prefsItem)

        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit SASS",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Enter Full Screen",
                         action: #selector(NSWindow.toggleFullScreen(_:)),
                         keyEquivalent: "f")

        NSApp.mainMenu = mainMenu
    }

    @objc private func openPreferences() {
        sassLog("openPreferences() called via menu")
        ConfigurationWindowController.shared.show()
    }

    // MARK: - Slideshow windows

    static weak var shared: AppDelegate?

    private func openWindowsForAllScreens() {
        for screen in NSScreen.screens {
            let win = ScreenWindow(screen: screen)
            win.makeKeyAndOrderFront(nil)
            screenWindows.append(win)
        }
    }

    /// Call when config UI is open — stops slideshow windows stealing focus.
    func freezeSlideshowWindows() {
        for win in screenWindows {
            win.ignoresMouseEvents = true
            win.resignKey()
            win.resignMain()
        }
    }

    /// Call when config UI is closed — restores normal slideshow behaviour.
    func unfreezeSlideshowWindows() {
        for win in screenWindows {
            win.ignoresMouseEvents = false
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        .terminateNow
    }
}
