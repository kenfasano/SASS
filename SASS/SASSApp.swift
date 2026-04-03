import SwiftUI
import AppKit
import IOKit.pwr_mgt

@main
struct SASSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty — windows are managed entirely by AppDelegate
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var screenWindows: [ScreenWindow] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMenuBar()
        openWindowsForAllScreens()
        NSApp.activate(ignoringOtherApps: true)
        
        let reasonForActivity = "SASS slideshow" as CFString
        var assertionID: IOPMAssertionID = 0
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reasonForActivity,
            &assertionID
        )
    }

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About SASS", action: #selector(NSApp.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit SASS", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // View menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")

        NSApp.mainMenu = mainMenu
    }

    private func openWindowsForAllScreens() {
        for screen in NSScreen.screens {
            let win = ScreenWindow(screen: screen)
            win.makeKeyAndOrderFront(nil)
            screenWindows.append(win)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
