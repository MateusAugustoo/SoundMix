import AppKit
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Escuro"
        }
    }

    var symbol: String {
        switch self {
        case .system: "desktopcomputer"
        case .light: "sun.max"
        case .dark: "moon.stars"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum SoundMixStyle {
    static let ink = adaptive(light: 0x292938, dark: 0xF5F0FB)
    static let muted = adaptive(light: 0x8A8799, dark: 0xB5ADC8)
    static let violet = adaptive(light: 0x7864D6, dark: 0xB8A7FF)
    static let violetDeep = adaptive(light: 0x614FB8, dark: 0xD0C3FF)
    static let panelSecondary = adaptive(light: 0x575266, dark: 0xC1B9D1)
    static let panelLabel = adaptive(light: 0x665C7A, dark: 0xAEA2C5)

    static let backdrop = adaptive(light: 0xE0DEF0, dark: 0x14101F)
    static let peachGlow = adaptive(light: 0xFFD1BD, dark: 0x653B52)
    static let violetGlow = adaptive(light: 0xB39EED, dark: 0x493473)
    static let blueGlow = adaptive(light: 0xA1C7F5, dark: 0x28436D)
    static let panelBackground = adaptive(light: 0xF5F0FC, dark: 0x191426, lightAlpha: 0.84, darkAlpha: 0.95)
    static let panelGradient = adaptive(light: 0xE3D6FF, dark: 0x67458E, lightAlpha: 0.16, darkAlpha: 0.15)

    static let contentTint = adaptive(light: 0xFFFFFF, dark: 0x100C1A, lightAlpha: 0.28, darkAlpha: 0.34)
    static let sidebarTint = adaptive(light: 0xFFFFFF, dark: 0x130F20, lightAlpha: 0.18, darkAlpha: 0.36)
    static let toolbarTint = adaptive(light: 0xFFFFFF, dark: 0x1C1629, lightAlpha: 0.12, darkAlpha: 0.40)
    static let surfaceTint = adaptive(light: 0xFFFFFF, dark: 0x2B223D, lightAlpha: 0.16, darkAlpha: 0.42)
    static let line = adaptive(light: 0xFFFFFF, dark: 0xD5C4F1, lightAlpha: 0.66, darkAlpha: 0.17)
    static let separator = adaptive(light: 0xFFFFFF, dark: 0xD5C4F1, lightAlpha: 0.58, darkAlpha: 0.16)
    static let selection = adaptive(light: 0xFFFFFF, dark: 0xA997D8, lightAlpha: 0.50, darkAlpha: 0.18)
    static let selectionLine = adaptive(light: 0xFFFFFF, dark: 0xD8C8FA, lightAlpha: 0.75, darkAlpha: 0.28)
    static let iconBackground = adaptive(light: 0xFFFFFF, dark: 0xE5D9FF, lightAlpha: 0.46, darkAlpha: 0.10)
    static let iconLine = adaptive(light: 0xFFFFFF, dark: 0xD8C8FA, lightAlpha: 0.62, darkAlpha: 0.21)
    static let sliderTrack = adaptive(light: 0xFFFFFF, dark: 0xD7C8F7, lightAlpha: 0.55, darkAlpha: 0.22)
    static let sliderThumb = adaptive(light: 0xFFFFFF, dark: 0xF2EBFF)
    static let switchOff = adaptive(light: 0xBBB2C9, dark: 0x59476F)
    static let switchOffLine = adaptive(light: 0x9186A4, dark: 0xB8A3D5)
    static let switchThumbOn = adaptive(light: 0xFFFFFF, dark: 0x241B34)
    static let switchThumbOff = adaptive(light: 0xFFFFFF, dark: 0xF4EEFF)
    static let cardGlow = adaptive(light: 0xFFFFFF, dark: 0x8F6CBA, lightAlpha: 0.08, darkAlpha: 0.11)
    static let shadow = adaptive(light: 0x483B6E, dark: 0x05030A, lightAlpha: 0.10, darkAlpha: 0.32)

    private static func adaptive(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        })
    }
}

struct PastelBackdrop: View {
    var body: some View {
        ZStack {
            SoundMixStyle.backdrop
            RadialGradient(colors: [SoundMixStyle.peachGlow.opacity(0.85), .clear], center: .topLeading, startRadius: 40, endRadius: 610)
            RadialGradient(colors: [SoundMixStyle.violetGlow.opacity(0.70), .clear], center: .topTrailing, startRadius: 25, endRadius: 650)
            RadialGradient(colors: [SoundMixStyle.blueGlow.opacity(0.48), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 570)
        }
        .ignoresSafeArea()
    }
}

struct SoftSurface: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(SoundMixStyle.surfaceTint, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(SoundMixStyle.line, lineWidth: 1)
            }
            .shadow(color: SoundMixStyle.shadow, radius: 18, y: 7)
    }
}

extension View {
    func softSurface(radius: CGFloat = 16) -> some View {
        modifier(SoftSurface(radius: radius))
    }

    @ViewBuilder
    func soundMixGlassButton() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func soundMixGlassCard(radius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
        }
    }
}

struct SymbolTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.49, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(SoundMixStyle.iconLine, lineWidth: 0.8)
            }
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SoundMixStyle.ink)
                Text(subtitle).font(.system(size: 11))
                    .foregroundStyle(SoundMixStyle.muted)
            }
            Spacer()
            if let action {
                Button("Ver todos  →", action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SoundMixStyle.violetDeep)
            }
        }
    }
}
