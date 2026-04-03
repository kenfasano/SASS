import SwiftUI
import AppKit

// MARK: - Data model for a displayed image layer

struct ImageLayer: Identifiable {
    let id = UUID()
    let image: NSImage
    let position: CGPoint
    let size: CGSize
    var opacity: Double
}

// MARK: - SlideshowView

struct SlideshowView: View {
    @StateObject private var controller = SlideshowController()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                ForEach(controller.layers) { layer in
                    Image(nsImage: layer.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: layer.size.width, height: layer.size.height)
                        .position(layer.position)
                        .opacity(layer.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                controller.start(viewSize: geo.size)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Controller

@MainActor
class SlideshowController: ObservableObject {
    @Published var layers: [ImageLayer] = []

    private var imageURLs: [URL] = []
    private var viewSize: CGSize = .zero
    private var slotTasks: [Task<Void, Never>] = []

    // Config
    private let slotCount = 21
    private let fibonacciSeconds: [Double] = [2, 3, 5, 8, 13, 21]
    private let fadeDuration: Double = 0.6

    // Image size as fraction of the screen's shorter dimension
    private let minSizeFraction: CGFloat = 0.10
    private let maxSizeFraction: CGFloat = 0.55

    func start(viewSize: CGSize) {
        self.viewSize = viewSize
        self.imageURLs = ImageLoader.loadImageURLs()
        guard !imageURLs.isEmpty else { return }

        // Cancel any existing slot tasks (e.g. on re-appear)
        slotTasks.forEach { $0.cancel() }
        slotTasks = []

        // Stagger slot starts so they don't all fire at once
        for slot in 0..<slotCount {
            let staggerDelay = Double(slot) * (fibonacciSeconds.max()! / Double(slotCount))
            let task = Task {
                // Initial stagger
                try? await Task.sleep(nanoseconds: UInt64(staggerDelay * 1_000_000_000))
                await runSlot()
            }
            slotTasks.append(task)
        }
    }

    /// Each slot loops independently: wait → show → hold → hide → repeat.
    private func runSlot() async {
        while !Task.isCancelled {
            // Wait before appearing
            let interval = fibonacciSeconds.randomElement()!
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            if Task.isCancelled { break }

            // Occasionally refresh image list so new ScreenArt output appears
            if Int.random(in: 0..<20) == 0 {
                let fresh = ImageLoader.loadImageURLs()
                if !fresh.isEmpty { imageURLs = fresh }
            }

            guard let url = imageURLs.randomElement(),
                  let nsImage = ImageLoader.loadImage(url: url) else { continue }

            let layerID = addLayer(image: nsImage)

            // Fade in
            withAnimation(.easeIn(duration: fadeDuration)) {
                setOpacity(id: layerID, opacity: 1.0)
            }

            // Hold
            let hold = fibonacciSeconds.randomElement()!
            try? await Task.sleep(nanoseconds: UInt64((hold + fadeDuration) * 1_000_000_000))

            // Fade out
            withAnimation(.easeOut(duration: fadeDuration)) {
                setOpacity(id: layerID, opacity: 0.0)
            }

            // Remove after fade completes
            try? await Task.sleep(nanoseconds: UInt64(fadeDuration * 1_000_000_000))
            layers.removeAll { $0.id == layerID }
        }
    }

    // MARK: - Layer helpers

    /// Adds a layer with opacity 0 and returns its ID.
    private func addLayer(image: NSImage) -> UUID {
        let layer = makeLayer(image: image)
        layers.append(layer)
        return layer.id
    }

    private func setOpacity(id: UUID, opacity: Double) {
        guard let idx = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[idx].opacity = opacity
    }

    private func makeLayer(image: NSImage) -> ImageLayer {
        let shorter = min(viewSize.width, viewSize.height)
        let fraction = CGFloat.random(in: minSizeFraction...maxSizeFraction)
        let targetDim = shorter * fraction

        let naturalSize = image.size
        let aspect = naturalSize.width / max(naturalSize.height, 1)
        let size: CGSize = aspect >= 1
            ? CGSize(width: targetDim * aspect, height: targetDim)
            : CGSize(width: targetDim, height: targetDim / aspect)

        let halfW = size.width / 2
        let halfH = size.height / 2
        let x = CGFloat.random(in: halfW...(viewSize.width - halfW))
        let y = CGFloat.random(in: halfH...(viewSize.height - halfH))

        return ImageLayer(image: image, position: CGPoint(x: x, y: y), size: size, opacity: 0.0)
    }
}
