import SwiftUI
import AppKit

// MARK: - Data model for a displayed image layer

struct ImageLayer: Identifiable {
    let id = UUID()
    let image: NSImage
    let position: CGPoint
    let size: CGSize
    var opacity: Double
    let transition: AnyTransition
}

// MARK: - Transition catalog

private let insertionTransitions: [AnyTransition] = [
    .opacity,
    .scale.combined(with: .opacity),
    .scale(scale: 0.5).combined(with: .opacity),
    .move(edge: .top).combined(with: .opacity),
    .move(edge: .bottom).combined(with: .opacity),
    .move(edge: .leading).combined(with: .opacity),
    .move(edge: .trailing).combined(with: .opacity),
    .slide.combined(with: .opacity),
    .offset(x: 80, y: 0).combined(with: .opacity),
    .offset(x: 0, y: 80).combined(with: .opacity),
]

private let removalTransitions: [AnyTransition] = [
    .opacity,
    .scale.combined(with: .opacity),
    .scale(scale: 0.5).combined(with: .opacity),
    .move(edge: .top).combined(with: .opacity),
    .move(edge: .bottom).combined(with: .opacity),
    .move(edge: .leading).combined(with: .opacity),
    .move(edge: .trailing).combined(with: .opacity),
    .slide.combined(with: .opacity),
    .offset(x: 80, y: 0).combined(with: .opacity),
    .offset(x: 0, y: 80).combined(with: .opacity),
]

private func randomTransition() -> AnyTransition {
    let insertion = insertionTransitions.randomElement()!
    let removal   = removalTransitions.randomElement()!
    return .asymmetric(insertion: insertion, removal: removal)
}

// MARK: - Animation catalog

private let insertionAnimations: [Animation] = [
    .easeIn(duration: 0.6),
    .easeInOut(duration: 0.6),
    .spring(response: 0.6, dampingFraction: 0.7),
    .bouncy,
]

private let removalAnimations: [Animation] = [
    .easeOut(duration: 0.6),
    .easeInOut(duration: 0.6),
    .linear(duration: 0.5),
]

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
                        .blendMode(.screen)
                        .transition(layer.transition)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear {
                controller.start(viewSize: geo.size)
            }
        }
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: .sassRestartSlideshow)) { _ in
            controller.restart()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sassPauseSlideshow)) { _ in
            controller.pause()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sassResumeSlideshow)) { _ in
            controller.resume()
        }
    }
}

// MARK: - Controller

@MainActor
class SlideshowController: ObservableObject {
    @Published var layers: [ImageLayer] = []

    private var imageURLs: [URL] = []
    private var viewSize: CGSize = .zero
    private var slotTasks: [Task<Void, Never>] = []

    // Settings are read fresh inside each slot loop, so live-updating is free.
    private var settings: AppSettings { AppSettings.shared }

    private var isPaused = false

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
    }

    func start(viewSize: CGSize) {
        self.viewSize = viewSize
        self.imageURLs = ImageLoader.loadImageURLs()
        spawnSlots()
    }

    func restart() {
        stopSlots()
        layers.removeAll()
        imageURLs = ImageLoader.loadImageURLs()
        spawnSlots()
    }

    private func spawnSlots() {
        guard !imageURLs.isEmpty else { return }

        let count = settings.slotCount
        let maxInterval = settings.maxInterval

        for slot in 0..<count {
            let staggerDelay = Double(slot) * (maxInterval / Double(count))
            let task = Task {
                try? await Task.sleep(nanoseconds: UInt64(staggerDelay * 1_000_000_000))
                await runSlot()
            }
            slotTasks.append(task)
        }
    }

    private func stopSlots() {
        slotTasks.forEach { $0.cancel() }
        slotTasks = []
    }

    private func runSlot() async {
        while !Task.isCancelled {
            // Read settings fresh each iteration so changes take effect without restart
            let s = settings

            let interval = Double.random(in: s.minInterval...s.maxInterval)
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            if Task.isCancelled { break }

            // Occasionally reload the image list (catches new files)
            if Int.random(in: 0..<20) == 0 {
                let fresh = ImageLoader.loadImageURLs()
                if !fresh.isEmpty { imageURLs = fresh }
            }

            // Don't touch the view while config dialog is open
            if isPaused { continue }

            guard let url = imageURLs.randomElement(),
                  let nsImage = ImageLoader.loadImage(url: url) else { continue }

            guard let layer = makeLayer(image: nsImage) else { continue }

            let insertAnim = insertionAnimations.randomElement()!
            let removeAnim = removalAnimations.randomElement()!

            // Fade in
            withAnimation(insertAnim) { layers.append(layer) }
            let layerID = layer.id

            // Hold
            let hold = Double.random(in: s.minHold...s.maxHold)
            try? await Task.sleep(nanoseconds: UInt64((hold + s.fadeDuration) * 1_000_000_000))
            if Task.isCancelled {
                withAnimation(removeAnim) { layers.removeAll { $0.id == layerID } }
                break
            }

            // Fade out (skip if paused — layer will stay frozen on screen)
            if !isPaused {
                withAnimation(removeAnim) { layers.removeAll { $0.id == layerID } }
            }

            // Wait for removal animation before looping
            try? await Task.sleep(nanoseconds: UInt64(s.fadeDuration * 1_000_000_000))
        }
    }

    // MARK: - Layer helpers

    private func makeLayer(image: NSImage) -> ImageLayer? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        let s = settings
        let shorter  = min(viewSize.width, viewSize.height)
        let fraction = CGFloat.random(in: s.minSizeFraction...s.maxSizeFraction)
        let targetDim = shorter * fraction

        let naturalSize = image.size
        let aspect = naturalSize.width / max(naturalSize.height, 1)

        var size: CGSize = aspect >= 1
            ? CGSize(width: targetDim * aspect, height: targetDim)
            : CGSize(width: targetDim, height: targetDim / aspect)
        size.width  = min(size.width,  viewSize.width)
        size.height = min(size.height, viewSize.height)

        let halfW = size.width  / 2
        let halfH = size.height / 2
        let xRange = halfW...max(halfW, viewSize.width  - halfW)
        let yRange = halfH...max(halfH, viewSize.height - halfH)

        return ImageLayer(
            image:      image,
            position:   CGPoint(x: CGFloat.random(in: xRange),
                                y: CGFloat.random(in: yRange)),
            size:       size,
            opacity:    1.0,
            transition: randomTransition()
        )
    }
}
