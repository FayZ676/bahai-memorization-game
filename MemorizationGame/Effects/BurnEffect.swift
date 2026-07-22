import SwiftUI

struct BurnDissolve: ViewModifier, Animatable {
    var progress: Double
    var seed: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.visualEffect { view, proxy in
            view.colorEffect(
                ShaderLibrary.burnDissolve(
                    .float2(proxy.size),
                    .float(Float(progress)),
                    .float(Float(seed))
                )
            )
        }
    }
}

extension View {
    func burnDissolve(progress: Double, seed: Double = 0) -> some View {
        modifier(BurnDissolve(progress: progress, seed: seed))
    }
}
