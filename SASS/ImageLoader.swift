import Foundation
import AppKit

struct ImageLoader {
    static let imageDirectory = URL(
        fileURLWithPath: "/Users/kenfasano/Scripts/ScreenArt/Images/TransformedImages"
    )

    /// Returns image URLs from the directory, sorted newest-first.
    static func loadImageURLs() -> [URL] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: imageDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let imageExtensions = Set(["jpg", "jpeg", "png", "heic", "tiff", "gif", "bmp", "webp"])
        let images = contents.filter { imageExtensions.contains($0.pathExtension.lowercased()) }

        return images.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return dateA > dateB
        }
    }

    /// Loads an NSImage from a URL, returns nil on failure.
    static func loadImage(url: URL) -> NSImage? {
        NSImage(contentsOf: url)
    }
}
