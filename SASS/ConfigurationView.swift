import SwiftUI
import AppKit

// MARK: - File logger (writes to /tmp/sass_debug.log)

func sassLog(_ message: String) {
    let logURL = URL(fileURLWithPath: "/tmp/sass_debug.log")
    let line = "\(Date()): \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    if FileManager.default.fileExists(atPath: logURL.path) {
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        }
    } else {
        try? data.write(to: logURL)
    }
}

// MARK: - Configuration Window Controller

final class ConfigurationWindowController: NSObject, NSWindowDelegate {
    static let shared = ConfigurationWindowController()
    private var window: NSWindow?

    private override init() {}

    func show() {
        sassLog("show() called")
        AppDelegate.shared?.freezeSlideshowWindows()
        NotificationCenter.default.post(name: .sassPauseSlideshow, object: nil)

        DispatchQueue.main.async {
            let screenInfo = NSScreen.screens.enumerated().map { i, s in
                "  [\(i)] \(s.localizedName) frame=\(s.frame) main=\(s == NSScreen.main)"
            }.joined(separator: "\n")
            sassLog("screens:\n\(screenInfo)")
            if let existing = self.window {
                sassLog("re-raising existing window, visible=\(existing.isVisible)")
                existing.level = .screenSaver + 1
                // Re-center on the screen with origin.x == 0
                let targetScreen = NSScreen.screens.first(where: { $0.frame.origin.x == 0 })
                                ?? NSScreen.main
                                ?? NSScreen.screens[0]
                let sf = targetScreen.visibleFrame
                let wf = existing.frame
                let x = sf.minX + (sf.width  - wf.width)  / 2
                let y = sf.minY + (sf.height - wf.height) / 2
                existing.setFrameOrigin(NSPoint(x: x, y: y))
                existing.orderFrontRegardless()
                existing.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            sassLog("creating new config window")
            let view    = ConfigurationView()
            let hosting = NSHostingView(rootView: view)
            hosting.sizingOptions = .preferredContentSize

            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                styleMask:   [.titled, .closable, .miniaturizable],
                backing:     .buffered,
                defer:       false
            )
            win.title                = "SASS Configuration"
            win.contentView          = hosting
            win.level                = .screenSaver + 1
            win.isReleasedWhenClosed = false
            win.delegate             = self

            // Pick the screen with the menu bar (origin.x == 0)
            // falling back to NSScreen.main if none found
            let targetScreen = NSScreen.screens.first(where: { $0.frame.origin.x == 0 })
                            ?? NSScreen.main
                            ?? NSScreen.screens[0]
            let sf = targetScreen.visibleFrame
            let wf = win.frame
            let x = sf.minX + (sf.width  - wf.width)  / 2
            let y = sf.minY + (sf.height - wf.height) / 2
            win.setFrameOrigin(NSPoint(x: x, y: y))
            sassLog("placing window on screen: \(targetScreen.localizedName) at (\(x), \(y))")
            win.orderFrontRegardless()
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            sassLog("window created — level=\(win.level.rawValue) frame=\(win.frame) screen=\(win.screen?.localizedName ?? "nil")")

            self.window = win
        }
    }

    // Unfreeze slideshow windows when config is closed
    func windowWillClose(_ notification: Notification) {
        sassLog("config window closing — unfreezing slideshow windows")
        AppDelegate.shared?.unfreezeSlideshowWindows()
        NotificationCenter.default.post(name: .sassResumeSlideshow, object: nil)
    }
}

// MARK: - Configuration View

struct ConfigurationView: View {
    @ObservedObject private var s = AppSettings.shared

    @State private var pathText: String = AppSettings.shared.imageDirectoryPath

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SASS")
                            .font(.title2.bold())
                        Text("Slideshow Art Screen Saver")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Image folder
                Section(header: sectionHeader("Image Source", icon: "folder")) {
                    HStack {
                        TextField("Path to images folder", text: $pathText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit { commitPath() }
                        Button("Browse…") { pickFolder() }
                            .controlSize(.regular)
                    }
                    .onChange(of: pathText) { commitPath() }

                    let exists = FileManager.default.fileExists(atPath: pathText)
                    Label(
                        exists ? "Folder found" : "Folder not found — no images will load",
                        systemImage: exists ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundColor(exists ? .green : .orange)
                }

                Divider()

                // Concurrency
                Section(header: sectionHeader("Concurrency", icon: "square.3.layers.3d")) {
                    LabeledSlider(
                        label:  "Concurrent slots",
                        detail: "Number of images shown simultaneously",
                        value:  Binding(get: { Double(s.slotCount) }, set: { s.slotCount = Int($0.rounded()) }),
                        range:  1...20, step: 1,
                        format: { "\(Int($0))" }
                    )
                }

                Divider()

                // Timing
                Section(header: sectionHeader("Timing", icon: "timer")) {
                    LabeledSlider(label: "Min interval", detail: "Shortest wait before a slot shows a new image",
                                  value: $s.minInterval, range: 0.5...30, step: 0.5,
                                  format: { String(format: "%.1f s", $0) })
                    LabeledSlider(label: "Max interval", detail: "Longest wait before a slot shows a new image",
                                  value: $s.maxInterval, range: 1...60, step: 0.5,
                                  format: { String(format: "%.1f s", $0) })
                    LabeledSlider(label: "Min hold", detail: "Shortest time an image stays on screen",
                                  value: $s.minHold, range: 0.5...30, step: 0.5,
                                  format: { String(format: "%.1f s", $0) })
                    LabeledSlider(label: "Max hold", detail: "Longest time an image stays on screen",
                                  value: $s.maxHold, range: 1...120, step: 1,
                                  format: { String(format: "%.0f s", $0) })
                    LabeledSlider(label: "Fade duration", detail: "How long the fade-in / fade-out animation takes",
                                  value: $s.fadeDuration, range: 0.1...3.0, step: 0.1,
                                  format: { String(format: "%.1f s", $0) })
                }

                Divider()

                // Image sizing
                Section(header: sectionHeader("Image Size", icon: "rectangle.arrowtriangle.2.outward")) {
                    LabeledSlider(
                        label: "Min size", detail: "Smallest image as % of screen's shorter edge",
                        value: Binding(get: { s.minSizeFraction * 100 }, set: { s.minSizeFraction = $0 / 100 }),
                        range: 5...50, step: 1, format: { String(format: "%.0f%%", $0) }
                    )
                    LabeledSlider(
                        label: "Max size", detail: "Largest image as % of screen's shorter edge",
                        value: Binding(get: { s.maxSizeFraction * 100 }, set: { s.maxSizeFraction = $0 / 100 }),
                        range: 20...100, step: 1, format: { String(format: "%.0f%%", $0) }
                    )
                }

                Divider()

                // Footer
                HStack {
                    Button("Restore Defaults") { restoreDefaults() }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Apply & Restart") {
                        s.sanitize()
                        NotificationCenter.default.post(name: .sassRestartSlideshow, object: nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(24)
        }
        .frame(width: 480)
        .onAppear { pathText = s.imageDirectoryPath }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.headline).foregroundColor(.primary)
    }

    private func commitPath() { s.imageDirectoryPath = pathText }

    private func pickFolder() {
        guard let configWindow = NSApp.windows.first(where: { $0.title == "SASS Configuration" }) else {
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        if FileManager.default.fileExists(atPath: s.imageDirectoryPath) {
            panel.directoryURL = URL(fileURLWithPath: s.imageDirectoryPath)
        }
        panel.beginSheetModal(for: configWindow) { response in
            if response == .OK, let url = panel.url {
                self.pathText = url.path
                self.commitPath()
            }
        }
    }

    private func restoreDefaults() {
        s.slotCount = 8; s.minInterval = 1.0; s.maxInterval = 13.0
        s.minHold = 1.0; s.maxHold = 13.0; s.fadeDuration = 0.6
        s.minSizeFraction = 0.10; s.maxSizeFraction = 0.55
        pathText = s.imageDirectoryPath
    }
}

// MARK: - Reusable labeled slider

private struct LabeledSlider: View {
    let label:  String
    let detail: String
    @Binding var value: Double
    let range:  ClosedRange<Double>
    let step:   Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(format(value))
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.accentColor)
                    .frame(width: 60, alignment: .trailing)
            }
            Slider(value: $value, in: range, step: step)
            Text(detail).font(.caption).foregroundColor(.secondary)
        }
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let sassRestartSlideshow = Notification.Name("sassRestartSlideshow")
    static let sassPauseSlideshow   = Notification.Name("sassPauseSlideshow")
    static let sassResumeSlideshow  = Notification.Name("sassResumeSlideshow")
}
