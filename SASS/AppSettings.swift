import Foundation
import Combine

/// Singleton that holds all user-configurable settings, persisted via UserDefaults.
/// Any part of the app can read from this; SlideshowController observes it.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // MARK: - Image source

    @Published var imageDirectoryPath: String {
        didSet { UserDefaults.standard.set(imageDirectoryPath, forKey: "imageDirectoryPath") }
    }

    // MARK: - Concurrency

    /// How many independent image slots run in parallel.
    @Published var slotCount: Int {
        didSet { UserDefaults.standard.set(slotCount, forKey: "slotCount") }
    }

    // MARK: - Timing

    /// Minimum seconds between a slot picking a new image to show.
    @Published var minInterval: Double {
        didSet { UserDefaults.standard.set(minInterval, forKey: "minInterval") }
    }

    /// Maximum seconds between a slot picking a new image to show.
    @Published var maxInterval: Double {
        didSet { UserDefaults.standard.set(maxInterval, forKey: "maxInterval") }
    }

    /// Minimum seconds an image stays visible (hold time).
    @Published var minHold: Double {
        didSet { UserDefaults.standard.set(minHold, forKey: "minHold") }
    }

    /// Maximum seconds an image stays visible (hold time).
    @Published var maxHold: Double {
        didSet { UserDefaults.standard.set(maxHold, forKey: "maxHold") }
    }

    /// Duration of fade-in and fade-out animations.
    @Published var fadeDuration: Double {
        didSet { UserDefaults.standard.set(fadeDuration, forKey: "fadeDuration") }
    }

    // MARK: - Image sizing

    /// Minimum image size as a fraction of the screen's shorter edge (0.05 … 0.50).
    @Published var minSizeFraction: Double {
        didSet { UserDefaults.standard.set(minSizeFraction, forKey: "minSizeFraction") }
    }

    /// Maximum image size as a fraction of the screen's shorter edge (0.20 … 1.00).
    @Published var maxSizeFraction: Double {
        didSet { UserDefaults.standard.set(maxSizeFraction, forKey: "maxSizeFraction") }
    }

    // MARK: - Init

    private init() {
        let ud = UserDefaults.standard

        imageDirectoryPath = ud.string(forKey: "imageDirectoryPath")
            ?? "/Users/kenfasano/Scripts/ScreenArt/Images/TransformedImages"

        slotCount    = ud.object(forKey: "slotCount")    as? Int    ?? 8
        minInterval  = ud.object(forKey: "minInterval")  as? Double ?? 1.0
        maxInterval  = ud.object(forKey: "maxInterval")  as? Double ?? 13.0
        minHold      = ud.object(forKey: "minHold")      as? Double ?? 1.0
        maxHold      = ud.object(forKey: "maxHold")      as? Double ?? 13.0
        fadeDuration = ud.object(forKey: "fadeDuration") as? Double ?? 0.6
        minSizeFraction = ud.object(forKey: "minSizeFraction") as? Double ?? 0.10
        maxSizeFraction = ud.object(forKey: "maxSizeFraction") as? Double ?? 0.55
    }

    // MARK: - Helpers

    var imageDirectoryURL: URL {
        URL(fileURLWithPath: imageDirectoryPath)
    }

    /// Clamp and fix any contradictory min/max pairs after the dialog closes.
    func sanitize() {
        if minInterval  > maxInterval  { maxInterval  = minInterval }
        if minHold      > maxHold      { maxHold      = minHold }
        if minSizeFraction > maxSizeFraction { maxSizeFraction = minSizeFraction }
        slotCount = max(1, min(slotCount, 20))
    }
}
