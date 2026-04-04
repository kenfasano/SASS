import SwiftUI

struct CheckerboardModifier: AnimatableModifier {
    var progress: CGFloat // 0 = fully hidden, 1 = fully visible
    let tileSize: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.mask(
            Canvas { ctx, size in
                let cols = Int(size.width  / tileSize) + 1
                let rows = Int(size.height / tileSize) + 1
                let total = cols * rows

                for row in 0..<rows {
                    for col in 0..<cols {
                        let index = row * cols + col
                        // Each tile reveals based on progress through total tiles
                        let threshold = CGFloat(index) / CGFloat(total)
                        guard progress > threshold else { continue }

                        let rect = CGRect(
                            x: CGFloat(col) * tileSize,
                            y: CGFloat(row) * tileSize,
                            width: tileSize,
                            height: tileSize
                        )
                        ctx.fill(Path(rect), with: .color(.white))
                    }
                }
            }
        )
    }
}

extension AnyTransition {
    static var checkerboard: AnyTransition {
        .modifier(
            active:   CheckerboardModifier(progress: 0, tileSize: 60),
            identity: CheckerboardModifier(progress: 1, tileSize: 60)
        )
    }
}
