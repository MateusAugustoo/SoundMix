import SwiftUI

enum SoundMixStyle {
    static let ink = Color(red: 0.16, green: 0.16, blue: 0.22)
    static let muted = Color(red: 0.54, green: 0.53, blue: 0.60)
    static let violet = Color(red: 0.47, green: 0.39, blue: 0.84)
    static let violetDeep = Color(red: 0.38, green: 0.31, blue: 0.72)
    static let line = Color.white.opacity(0.66)
}

struct PastelBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.88, green: 0.87, blue: 0.94)
            RadialGradient(colors: [Color(red: 1.00, green: 0.82, blue: 0.74).opacity(0.85), .clear], center: .topLeading, startRadius: 40, endRadius: 610)
            RadialGradient(colors: [Color(red: 0.70, green: 0.62, blue: 0.93).opacity(0.70), .clear], center: .topTrailing, startRadius: 25, endRadius: 650)
            RadialGradient(colors: [Color(red: 0.63, green: 0.78, blue: 0.96).opacity(0.48), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 570)
        }
        .ignoresSafeArea()
    }
}

struct SoftSurface: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(SoundMixStyle.line, lineWidth: 1)
            }
            .shadow(color: Color(red: 0.28, green: 0.23, blue: 0.43).opacity(0.10), radius: 18, y: 7)
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
                    .strokeBorder(.white.opacity(0.62), lineWidth: 0.8)
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
