import AppKit
import SwiftUI

private enum QuickTab: String, CaseIterable {
    case general = "Geral"
    case apps = "Aplicativos"
    case outputs = "Saídas"
}

struct MenuBarPanel: View {
    @EnvironmentObject private var mixer: MixerModel
    @Environment(\.openWindow) private var openWindow
    @State private var tab: QuickTab = .general

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            SoundMixStyle.panelBackground
            LinearGradient(
                colors: [SoundMixStyle.cardGlow, SoundMixStyle.panelGradient, SoundMixStyle.cardGlow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(colors: [SoundMixStyle.violetGlow.opacity(0.20), .clear], center: .topLeading, startRadius: 20, endRadius: 260)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 31, height: 31)
                        .background(LinearGradient(colors: [.purple.opacity(0.72), SoundMixStyle.violetDeep], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sound Mix")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(SoundMixStyle.ink)
                        Text("Controle rápido de áudio")
                            .font(.system(size: 10))
                            .foregroundStyle(SoundMixStyle.panelSecondary)
                    }
                    Spacer()
                    Circle().fill(mixer.outputConnected ? Color.green.opacity(0.75) : Color.orange.opacity(0.75)).frame(width: 7, height: 7)
                }

                HStack(spacing: 3) {
                    ForEach(QuickTab.allCases, id: \.self) { item in
                        Button { tab = item } label: {
                            Text(item.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(tab == item ? SoundMixStyle.violetDeep : SoundMixStyle.panelSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 28)
                                .background {
                                    if tab == item {
                                        RoundedRectangle(cornerRadius: 7)
                                            .fill(SoundMixStyle.selection)
                                            .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(SoundMixStyle.selectionLine) }
                                            .shadow(color: SoundMixStyle.violetDeep.opacity(0.10), radius: 4, y: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(SoundMixStyle.surfaceTint, in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(SoundMixStyle.line) }

                Group {
                    switch tab {
                    case .general: generalContent
                    case .apps: appsContent
                    case .outputs: outputsContent
                    }
                }

                Rectangle().fill(SoundMixStyle.separator).frame(height: 1)
                HStack {
                    Button {
                        openWindow(id: "main")
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    } label: {
                        Text("Abrir janela do Sound Mix")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SoundMixStyle.violetDeep)
                    .buttonStyle(.plain)

                    Spacer()

                    Button("Sair") { NSApplication.shared.terminate(nil) }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(SoundMixStyle.panelSecondary)
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .frame(width: 356)
    }

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("VOLUME DO SISTEMA")
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    SymbolTile(symbol: "speaker.wave.2", tint: SoundMixStyle.violet, size: 26)
                    Text("Volume geral")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SoundMixStyle.ink)
                    Spacer()
                    Text(mixer.outputConnected ? "\(Int(mixer.masterVolume.rounded()))%" : "—")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(SoundMixStyle.violetDeep)
                }
                HStack(spacing: 8) {
                    Button { mixer.toggleMasterMute() } label: {
                        Image(systemName: mixer.isMasterSilent ? "speaker.slash" : "speaker.wave.1")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mixer.isMasterSilent ? "Ativar volume geral" : "Silenciar volume geral")
                    .disabled(!mixer.canToggleMasterMute)
                    GlassVolumeSlider(value: mixer.masterBinding, label: "Volume geral", enabled: mixer.canControlMasterVolume)
                }
                .font(.system(size: 13))
                .foregroundStyle(SoundMixStyle.panelSecondary)
                if mixer.outputConnected && !mixer.canControlMasterVolume {
                    Text("Este dispositivo não permite ajustar o volume pelo macOS.")
                        .font(.system(size: 9))
                        .foregroundStyle(SoundMixStyle.panelSecondary)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 3)
            .padding(.bottom, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(SoundMixStyle.separator).frame(height: 1)
            }

            sectionLabel("VOLUME POR APLICATIVO")
            VStack(spacing: 0) {
                ForEach(Array(mixer.apps.prefix(3).enumerated()), id: \.element.id) { index, app in
                    QuickAppRow(app: app)
                    if index < min(mixer.apps.count, 3) - 1 { Rectangle().fill(SoundMixStyle.separator).frame(height: 1) }
                }
                if mixer.apps.isEmpty { emptyApplications }
            }
            Button { tab = .apps } label: {
                HStack {
                    Text("Ver todos os aplicativos")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SoundMixStyle.violetDeep)
            }
            .buttonStyle(.plain)
        }
    }

    private var appsContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionLabel("VOLUME POR APLICATIVO")
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(mixer.apps.enumerated()), id: \.element.id) { index, app in
                        QuickAppRow(app: app)
                        if index < mixer.apps.count - 1 { Rectangle().fill(SoundMixStyle.separator).frame(height: 1) }
                    }
                    if mixer.apps.isEmpty { emptyApplications }
                }
            }
            .frame(maxHeight: 320)
            .scrollIndicators(.hidden)
        }
    }

    private var emptyApplications: some View {
        Text("Nenhum aplicativo usando saída de áudio no momento.")
            .font(.system(size: 10))
            .foregroundStyle(SoundMixStyle.panelSecondary)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
    }

    private var outputsContent: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionLabel("REPRODUZIR EM")
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(mixer.outputs) { output in
                        let isSelected = mixer.selectedOutputID == output.id
                        Button { mixer.selectOutput(output.id) } label: {
                            HStack(spacing: 9) {
                                SymbolTile(symbol: output.symbol, tint: SoundMixStyle.violet, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(output.shortName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(SoundMixStyle.ink)
                                    Text(isSelected ? "Saída atual · \(output.detail)" : output.detail)
                                        .font(.system(size: 9))
                                        .foregroundStyle(SoundMixStyle.panelSecondary)
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(SoundMixStyle.violet)
                                }
                            }
                            .padding(.horizontal, 7)
                            .frame(height: 54)
                            .background(isSelected ? SoundMixStyle.violet.opacity(0.10) : SoundMixStyle.surfaceTint,
                                        in: RoundedRectangle(cornerRadius: 9))
                            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(SoundMixStyle.line) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isSelected ? "Saída atual: \(output.name)" : "Selecionar \(output.name) como saída de áudio")
                    }
                    if mixer.outputs.isEmpty {
                        Text("Nenhuma saída de áudio disponível")
                            .font(.system(size: 10))
                            .foregroundStyle(SoundMixStyle.panelSecondary)
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                }
            }
            .frame(maxHeight: 320)
            .scrollIndicators(.hidden)
            if let error = mixer.outputSelectionError {
                Text(error).font(.system(size: 9)).foregroundStyle(.red)
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(SoundMixStyle.panelLabel)
            .padding(.leading, 2)
    }
}

private struct QuickAppRow: View {
    @EnvironmentObject private var mixer: MixerModel
    let app: AudioApplication

    var body: some View {
        HStack(spacing: 8) {
            AudioApplicationIcon(app: app, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SoundMixStyle.ink)
                Text(mixer.appErrors[app.id] ?? app.detail)
                    .font(.system(size: 9))
                    .foregroundStyle(mixer.appErrors[app.id] == nil ? SoundMixStyle.panelSecondary : .red)
                    .lineLimit(1)
            }
            .frame(width: 94, alignment: .leading)
            GlassVolumeSlider(value: mixer.volumeBinding(for: app.id), label: "Volume de \(app.name)", enabled: mixer.outputConnected)
            Text("\(Int((mixer.appVolumes[app.id] ?? 100).rounded()))%")
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(SoundMixStyle.panelSecondary)
                .frame(width: 34, alignment: .trailing)
            Button { mixer.toggleAppMute(app.id) } label: {
                Image(systemName: (mixer.appVolumes[app.id] ?? 100) < 0.5 ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: 11))
                    .foregroundStyle(SoundMixStyle.panelSecondary)
                    .frame(width: 18, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(!mixer.outputConnected)
            .accessibilityLabel((mixer.appVolumes[app.id] ?? 100) < 0.5 ? "Ativar \(app.name)" : "Silenciar \(app.name)")
        }
        .frame(height: 54)
    }
}

private struct GlassVolumeSlider: View {
    @Binding var value: Double
    let label: String
    var enabled = true

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = max(1, geometry.size.width - 16)
            let progress = min(max(value / 100, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SoundMixStyle.sliderTrack)
                    .frame(height: 6)
                Capsule()
                    .fill(SoundMixStyle.violet.opacity(0.88))
                    .frame(width: 8 + trackWidth * progress, height: 6)
                Circle()
                    .fill(SoundMixStyle.sliderThumb)
                    .frame(width: 16, height: 16)
                    .shadow(color: SoundMixStyle.violetDeep.opacity(0.16), radius: 5, y: 2)
                    .offset(x: trackWidth * progress)
            }
            .frame(height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard enabled else { return }
                        value = min(max((gesture.location.x - 8) / trackWidth * 100, 0), 100)
                    }
            )
        }
        .frame(height: 20)
        .opacity(enabled ? 1 : 0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value))%")
        .accessibilityAdjustableAction { direction in
            guard enabled else { return }
            switch direction {
            case .increment: value = min(value + 5, 100)
            case .decrement: value = max(value - 5, 0)
            @unknown default: break
            }
        }
    }
}
