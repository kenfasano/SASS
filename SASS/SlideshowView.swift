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
    private let slotCount = 8
    private let fibonacciSeconds: [Double] = [1, 2, 3, 5, 8, 13]
    private let fadeDuration: Double = 0.6

    // Image size as fraction of the screen's shorter dimension
    private let minSizeFraction: CGFloat = 0.10
    private let maxSizeFraction: CGFloat = 0.55

    func start(viewSize: CGSize) {
        self.viewSize = viewSize
        self.imageURLs = ImageLoader.loadImageURLs()
        guard !imageURLs.isEmpty else { return }

        slotTasks.forEach { $0.cancel() }
        slotTasks = []

        for slot in 0..<slotCount {
            let staggerDelay = Double(slot) * (fibonacciSeconds.max()! / Double(slotCount))
            let task = Task {
                try? await Task.sleep(nanoseconds: UInt64(staggerDelay * 1_000_000_000))
                await runSlot()
            }
            slotTasks.append(task)
        }
    }

    private func runSlot() async {
        while !Task.isCancelled {
            let interval = fibonacciSeconds.randomElement()!
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            if Task.isCancelled { break }

            if Int.random(in: 0..<20) == 0 {
                let fresh = ImageLoader.loadImageURLs()
                if !fresh.isEmpty { imageURLs = fresh }
            }

            guard let url = imageURLs.randomElement(),
                  let nsImage = ImageLoader.loadImage(url: url) else { continue }

            guard let layer = makeLayer(image: nsImage) else { continue }

            let insertAnim = insertionAnimations.randomElement()!
            let removeAnim = removalAnimations.randomElement()!

            // Fade in with random insertion animation
            withAnimation(insertAnim) {
                layers.append(layer)
            }
            let layerID = layer.id

            // Hold
            let hold = fibonacciSeconds.randomElement()!
            try? await Task.sleep(nanoseconds: UInt64((hold + fadeDuration) * 1_000_000_000))

            // Fade out with random removal animation
            withAnimation(removeAnim) {
                layers.removeAll { $0.id == layerID }
            }

            // Wait for removal animation to complete before looping
            try? await Task.sleep(nanoseconds: UInt64(fadeDuration * 1_000_000_000))
        }
    }

    // MARK: - Layer helpers

    private func makeLayer(image: NSImage) -> ImageLayer? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        let shorter = min(viewSize.width, viewSize.height)
        let fraction = CGFloat.random(in: minSizeFraction...maxSizeFraction)
        let targetDim = shorter * fraction

        let naturalSize = image.size
        let aspect = naturalSize.width / max(naturalSize.height, 1)

        var size: CGSize = aspect >= 1
            ? CGSize(width: targetDim * aspect, height: targetDim)
            : CGSize(width: targetDim, height: targetDim / aspect)
        size.width  = min(size.width,  viewSize.width)
        size.height = min(size.height, viewSize.height)

        let halfW = size.width / 2
        let halfH = size.height / 2

        let xRange = halfW...max(halfW, viewSize.width  - halfW)
        let yRange = halfH...max(halfH, viewSize.height - halfH)

        let x = CGFloat.random(in: xRange)
        let y = CGFloat.random(in: yRange)

        return ImageLayer(
            image: image,
            position: CGPoint(x: x, y: y),
            size: size,
            opacity: 1.0,
            transition: randomTransition()
        )
    }
}
