import SwiftUI

struct RollTransition: ViewModifier {
    let offsetX: CGFloat
    let rotation: Double // degrees

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .rotationEffect(.degrees(rotation), anchor: .center)
    }
}

extension AnyTransition {
    static func rollOff(edge: Edge) -> AnyTransition {
        let sign: CGFloat = edge == .leading ? -1 : 1
        return .modifier(
            active: RollTransition(offsetX: sign * 600, rotation: sign * 360),
            identity: RollTransition(offsetX: 0, rotation: 0)
        )
    }
}

// Usage:
// .asymmetric(insertion: .rollOff(edge: .leading), removal: .rollOff(edge: .trailing))
