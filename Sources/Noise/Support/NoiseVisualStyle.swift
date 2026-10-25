import AppKit
import SwiftUI

enum NoisePalette {
    static let background = adaptive(0xFAF9F6, 0x1C1E1C)
    static let sidebar = adaptive(0xF0F0EA, 0x242623)
    static let surface = adaptive(0xFFFFFF, 0x292C28)
    static let text = adaptive(0x292F29, 0xEDF0E8)
    static let secondary = adaptive(0x626C61, 0xB0B9AC)
    static let separator = adaptive(0xE2E5DC, 0x41473D)
    static let selection = adaptive(0xE6ECDF, 0x343E2E)
    static let primary = adaptive(0x344C35, 0xB9CEA7)
    static let onPrimary = adaptive(0xFFFFFF, 0x202A1C)
    static let focus = adaptive(0xB76032, 0xF2A36F)
    static let rest = adaptive(0x537B67, 0x8FC7B1)
    static let longRest = adaptive(0x617D8A, 0xABC4D0)

    static func accent(for mode: NoiseTimerMode) -> Color {
        switch mode {
        case .focus: return focus
        case .shortBreak: return rest
        case .longBreak: return longRest
        }
    }

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

struct NoisePanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(NoisePalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(NoisePalette.separator, lineWidth: 1)
            )
    }
}

extension View {
    func noisePanel() -> some View { modifier(NoisePanel()) }
}

struct NoisePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .frame(width: 158, height: 42)
            .foregroundStyle(NoisePalette.onPrimary)
            .background(NoisePalette.primary.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct NoiseSettingsButton: View {
    var body: some View {
        Group {
            if #available(macOS 14.0, *) {
                SettingsLink { label }
            } else {
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: { label }
            }
        }
        .buttonStyle(.plain)
        .help("设置（⌘,）")
        .accessibilityLabel("设置")
    }

    private var label: some View {
        Image(systemName: "slider.horizontal.3")
            .font(.system(size: 14))
            .foregroundStyle(NoisePalette.secondary)
            .frame(width: 32, height: 30)
            .contentShape(Rectangle())
    }
}
