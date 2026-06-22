import SwiftUI

struct NoisePanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 1)
            )
    }
}

extension View {
    func noisePanel() -> some View {
        modifier(NoisePanel())
    }
}

enum NoisePalette {
    static let focus = Color.orange
    static let rest = Color.teal
    static let longRest = Color.blue

    static func accent(for mode: NoiseTimerMode) -> Color {
        switch mode {
        case .focus:
            return focus
        case .shortBreak:
            return rest
        case .longBreak:
            return longRest
        }
    }
}
