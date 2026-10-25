import SwiftUI

enum SoundMixPage: String, CaseIterable {
    case overview = "Visão geral"
    case apps = "Aplicativos"
    case outputs = "Saídas de áudio"
    case scenes = "Cenas"
    case settings = "Ajustes"

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .apps: "square.grid.3x3"
        case .outputs: "speaker.wave.2"
        case .scenes: "sparkles"
        case .settings: "gearshape"
        }
    }
}

struct MainWindowView: View {
    @EnvironmentObject private var mixer: MixerModel
    @State private var page: SoundMixPage = .overview
    @State private var search = ""

    var body: some View {
        ZStack {
            PastelBackdrop()
            HStack(spacing: 0) {
                sidebar.frame(width: 224)
                VStack(spacing: 0) {
                    toolbar
                    ScrollView {
                        Group {
                            switch page {
                            case .overview: overview
                            case .apps: appsPage
                            case .outputs: outputsPage
                            case .scenes: scenesPage
                            case .settings: settingsPage
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 35)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollIndicators(.hidden)
                }
                .background(Color.white.opacity(0.28))
            }
        }
        .frame(minWidth: 1040, minHeight: 700)
        .preferredColorScheme(.light)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 43)
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 31, height: 31)
                    .background(LinearGradient(colors: [.purple.opacity(0.7), SoundMixStyle.violetDeep], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 9))
                Text("Sound Mix")
                    .font(.system(size: 18, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(SoundMixStyle.ink)
            }
            .padding(.horizontal, 17)
            .padding(.bottom, 39)

            Text("BIBLIOTECA")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(SoundMixStyle.muted)
                .padding(.horizontal, 22)
                .padding(.bottom, 10)

            ForEach([SoundMixPage.overview, .apps, .outputs, .scenes], id: \.self) { navButton($0) }
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                SymbolTile(symbol: "waveform", tint: SoundMixStyle.violet, size: 26)
                Text("Seu som, do seu jeito.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SoundMixStyle.ink)
                Text("Ajuste o áudio de cada aplicativo em um só lugar.")
                    .font(.system(size: 10))
                    .foregroundStyle(SoundMixStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .softSurface(radius: 14)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            navButton(.settings)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 13)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.18))
        .overlay(alignment: .trailing) { Rectangle().fill(.white.opacity(0.65)).frame(width: 1) }
    }

    private func navButton(_ destination: SoundMixPage) -> some View {
        Button { page = destination } label: {
            HStack(spacing: 12) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 17))
                    .frame(width: 19)
                    .foregroundStyle(page == destination ? SoundMixStyle.violet : SoundMixStyle.muted)
                Text(destination.rawValue)
                    .font(.system(size: 13, weight: page == destination ? .semibold : .medium))
                    .foregroundStyle(page == destination ? SoundMixStyle.ink : SoundMixStyle.muted)
                Spacer(minLength: 0)
                if destination == .apps {
                Text("\(mixer.apps.count)").font(.system(size: 10)).foregroundStyle(SoundMixStyle.muted)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 39)
            .background(page == destination ? Color.white.opacity(0.50) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if page == destination {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.75), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text("Sound Mix").foregroundStyle(SoundMixStyle.muted)
            Text("/").foregroundStyle(SoundMixStyle.muted.opacity(0.55))
            Text(page.rawValue).fontWeight(.semibold).foregroundStyle(SoundMixStyle.ink)
            Spacer()
            Circle().fill(mixer.outputConnected ? Color.green.opacity(0.75) : Color.orange.opacity(0.75)).frame(width: 7, height: 7)
            Text(mixer.outputConnected ? "Saída conectada" : "Sem saída de áudio").foregroundStyle(SoundMixStyle.muted)
            Button { page = .settings } label: {
                Image(systemName: "info.circle").font(.system(size: 15)).frame(width: 30, height: 30)
            }
            .soundMixGlassButton()
            .tint(SoundMixStyle.violet)
            .accessibilityLabel("Sobre o Sound Mix")
            .padding(.leading, 9)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 32)
        .frame(height: 66)
        .background(Color.white.opacity(0.12))
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.55)).frame(height: 1) }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 25) {
            HStack(alignment: .bottom) {
                intro(eyebrow: Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "pt_BR"))).uppercased(), title: "Bom som começa aqui.", subtitle: "Ajuste os aplicativos e a saída principal.")
                Spacer()
                HStack(spacing: 7) {
                    Image(systemName: "waveform").foregroundStyle(SoundMixStyle.violet)
                    Text(mixer.outputConnected ? "Saída conectada" : "Sem saída de áudio")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(SoundMixStyle.muted)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .softSurface(radius: 16)
            }

            HStack(alignment: .top, spacing: 21) {
                VStack(alignment: .leading, spacing: 27) {
                    MasterCard { page = .outputs }
                    VStack(spacing: 14) {
                        SectionHeading(title: "Mix de aplicativos", subtitle: "Volume individual dos apps com áudio") { page = .apps }
                        AppList(apps: Array(mixer.apps.prefix(4)))
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 27) {
                    VStack(spacing: 14) {
                        SectionHeading(title: "Saídas de áudio", subtitle: "Escolha onde ouvir")
                        OutputList()
                    }
                    VStack(spacing: 14) {
                        SectionHeading(title: "Cenas rápidas", subtitle: "Um toque, outro clima")
                        VStack(spacing: 8) {
                            ForEach(mixer.scenes) { scene in SceneRow(scene: scene) }
                        }
                    }
                }
                .frame(width: 264)
            }
        }
        .padding(.top, 32)
    }

    private var appsPage: some View {
        VStack(alignment: .leading, spacing: 26) {
            intro(eyebrow: "VOLUME INDIVIDUAL", title: "Aplicativos", subtitle: "Ajuste cada app com áudio. O primeiro ajuste solicita acesso ao áudio do sistema.")
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Buscar aplicativo", text: $search).textFieldStyle(.plain)
            }
            .font(.system(size: 12))
            .foregroundStyle(SoundMixStyle.muted)
            .padding(10)
            .frame(width: 260)
            .softSurface(radius: 9)
            AppList(apps: mixer.apps.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) })
        }
        .padding(.top, 40)
    }

    private var outputsPage: some View {
        VStack(alignment: .leading, spacing: 26) {
            intro(eyebrow: "DISPOSITIVO PADRÃO", title: "Saída de áudio", subtitle: "Escolha onde reproduzir o áudio do Mac.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 13)], spacing: 13) {
                ForEach(mixer.outputs) { output in
                    let isSelected = mixer.selectedOutputID == output.id
                    Button { mixer.selectOutput(output.id) } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            SymbolTile(symbol: output.symbol, tint: SoundMixStyle.violet, size: 40)
                            Spacer()
                            Text(output.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(SoundMixStyle.ink)
                                .lineLimit(2)
                            Text(output.detail).font(.system(size: 10)).foregroundStyle(SoundMixStyle.muted)
                            Text(isSelected ? "✓ Saída padrão" : "Selecionar saída →")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(SoundMixStyle.violetDeep)
                        }
                        .padding(17)
                        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
                        .softSurface(radius: 15)
                        .overlay {
                            RoundedRectangle(cornerRadius: 15)
                                .strokeBorder(SoundMixStyle.violet.opacity(isSelected ? 0.55 : 0), lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSelected ? "Saída atual: \(output.name)" : "Selecionar \(output.name) como saída de áudio")
                }
            }
            if let error = mixer.outputSelectionError {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
            }
            if mixer.outputs.isEmpty {
                Text("Nenhuma saída de áudio está disponível no momento.")
                    .font(.system(size: 12)).foregroundStyle(SoundMixStyle.muted)
            }
        }
        .padding(.top, 40)
    }

    private var scenesPage: some View {
        VStack(alignment: .leading, spacing: 26) {
            intro(eyebrow: "AJUSTES EM UM TOQUE", title: "Cenas", subtitle: "Mude o clima sem ajustar cada controle.")
            HStack(spacing: 14) {
                ForEach(mixer.scenes) { scene in
                    Button { mixer.apply(scene) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            SymbolTile(symbol: scene.symbol, tint: scene.tint, size: 43)
                            Spacer()
                            Text(scene.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(SoundMixStyle.ink)
                            Text(scene.description).font(.system(size: 11)).foregroundStyle(SoundMixStyle.muted)
                            Text(mixer.selectedSceneID == scene.id ? "✓ Cena ativa" : "Aplicar cena →")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(SoundMixStyle.violetDeep)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, minHeight: 212, alignment: .leading)
                        .softSurface(radius: 17)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("As cenas ajustam o volume real da saída padrão do macOS.")
                .font(.system(size: 11)).foregroundStyle(SoundMixStyle.muted)
        }
        .padding(.top, 40)
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 26) {
            intro(eyebrow: "PREFERÊNCIAS", title: "Ajustes", subtitle: "Deixe o Sound Mix com a sua cara.")
            SettingsPanel()
            Text("O volume principal controla a saída padrão do macOS. O controle individual usa a permissão de gravação do áudio do sistema.")
                .font(.system(size: 11)).foregroundStyle(SoundMixStyle.muted)
        }
        .padding(.top, 40)
    }

    private func intro(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow).font(.system(size: 10, weight: .bold)).tracking(1.2).foregroundStyle(SoundMixStyle.violet)
            Text(title).font(.system(size: 31, weight: .bold)).tracking(-1.4).foregroundStyle(SoundMixStyle.ink)
            Text(subtitle).font(.system(size: 12)).foregroundStyle(SoundMixStyle.muted)
        }
    }
}

struct MasterCard: View {
    @EnvironmentObject private var mixer: MixerModel
    var onChangeOutput: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                SymbolTile(symbol: "speaker.wave.2", tint: SoundMixStyle.violet, size: 29)
                Text("SAÍDA PRINCIPAL")
                    .font(.system(size: 9, weight: .bold)).tracking(1.1).foregroundStyle(SoundMixStyle.muted)
                Spacer()
                if let onChangeOutput {
                    Button("Ver saída  ›", action: onChangeOutput)
                        .font(.system(size: 10, weight: .semibold)).soundMixGlassButton().tint(SoundMixStyle.violet)
                }
            }
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mixer.selectedOutput.name)
                        .font(.system(size: 20, weight: .semibold)).tracking(-0.6)
                        .foregroundStyle(SoundMixStyle.ink).lineLimit(1)
                    Text(mixer.selectedOutput.detail).font(.system(size: 11)).foregroundStyle(SoundMixStyle.muted)
                }
                Spacer()
                Text(mixer.outputConnected ? "\(Int(mixer.masterVolume.rounded()))%" : "—")
                    .font(.system(size: 34, weight: .medium)).monospacedDigit()
                    .foregroundStyle(SoundMixStyle.violetDeep)
            }
            HStack(spacing: 10) {
                Button { mixer.toggleMasterMute() } label: {
                    Image(systemName: mixer.isMasterSilent ? "speaker.slash" : "speaker.wave.1")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mixer.isMasterSilent ? "Ativar volume geral" : "Silenciar volume geral")
                .disabled(!mixer.canToggleMasterMute)
                Slider(value: mixer.masterBinding, in: 0...100)
                    .tint(SoundMixStyle.violet).accessibilityLabel("Volume geral")
                    .disabled(!mixer.canControlMasterVolume)
                Image(systemName: "speaker.wave.3").font(.system(size: 15))
            }
            .foregroundStyle(SoundMixStyle.muted)
            .padding(.top, 15)
        }
        .padding(21)
        .frame(height: 191)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 19)
                .fill(RadialGradient(colors: [SoundMixStyle.violet.opacity(0.23), .white.opacity(0.08)], center: .bottomTrailing, startRadius: 10, endRadius: 380))
        }
        .soundMixGlassCard(radius: 19)
        .overlay { RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(0.8), lineWidth: 1) }
        .shadow(color: SoundMixStyle.violetDeep.opacity(0.14), radius: 20, y: 10)
    }
}

struct AppList: View {
    let apps: [AudioApplication]
    var body: some View {
        LazyVStack(spacing: 0) {
            if apps.isEmpty {
                Text("Nenhum aplicativo usando saída de áudio no momento.")
                    .font(.system(size: 11))
                    .foregroundStyle(SoundMixStyle.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            } else {
                ForEach(apps) { app in
                    AudioApplicationRow(app: app)
                    if app.id != apps.last?.id { Rectangle().fill(.white.opacity(0.58)).frame(height: 1) }
                }
            }
        }
        .softSurface(radius: 16)
    }
}

struct AudioApplicationIcon: View {
    let app: AudioApplication
    let size: CGFloat

    var body: some View {
        Group {
            if let icon = app.icon {
                Image(nsImage: icon).resizable().scaledToFit()
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(SoundMixStyle.violetDeep)
            }
        }
        .frame(width: size, height: size)
        .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: size * 0.25))
    }
}

struct AudioApplicationRow: View {
    @EnvironmentObject private var mixer: MixerModel
    let app: AudioApplication
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 7 : 11) {
            AudioApplicationIcon(app: app, size: compact ? 30 : 37)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold))
                    .foregroundStyle(SoundMixStyle.ink).lineLimit(1)
                Text(mixer.appErrors[app.id] ?? app.detail)
                    .font(.system(size: compact ? 8 : 9))
                    .foregroundStyle(mixer.appErrors[app.id] == nil ? SoundMixStyle.muted : .red).lineLimit(1)
            }
            .frame(width: compact ? 86 : 145, alignment: .leading)
            Slider(value: mixer.volumeBinding(for: app.id), in: 0...100)
                .tint(SoundMixStyle.violet)
                .accessibilityLabel("Volume de \(app.name)")
                .disabled(!mixer.outputConnected)
            Text("\(Int((mixer.appVolumes[app.id] ?? 100).rounded()))%")
                .font(.system(size: compact ? 9 : 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(SoundMixStyle.violetDeep)
                .frame(width: compact ? 28 : 34, alignment: .trailing)
            Button { mixer.toggleAppMute(app.id) } label: {
                Image(systemName: (mixer.appVolumes[app.id] ?? 100) < 0.5 ? "speaker.slash" : "speaker.wave.2")
                    .font(.system(size: compact ? 12 : 14))
                    .foregroundStyle(SoundMixStyle.muted)
            }
            .buttonStyle(.plain)
            .disabled(!mixer.outputConnected)
            .accessibilityLabel((mixer.appVolumes[app.id] ?? 100) < 0.5 ? "Ativar \(app.name)" : "Silenciar \(app.name)")
        }
        .padding(.horizontal, compact ? 2 : 15)
        .frame(height: compact ? 54 : 66)
    }
}

struct OutputList: View {
    @EnvironmentObject private var mixer: MixerModel
    var body: some View {
        VStack(spacing: 2) {
            ForEach(mixer.outputs) { output in
                let isSelected = mixer.selectedOutputID == output.id
                Button { mixer.selectOutput(output.id) } label: {
                    HStack(spacing: 9) {
                        SymbolTile(symbol: output.symbol, tint: SoundMixStyle.violet, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(output.shortName)
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(SoundMixStyle.ink).lineLimit(1)
                            Text(isSelected ? "Saída atual · \(output.detail)" : output.detail)
                                .font(.system(size: 9)).foregroundStyle(SoundMixStyle.muted).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if isSelected {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                                .foregroundStyle(SoundMixStyle.violet)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 55)
                    .background(isSelected ? SoundMixStyle.violet.opacity(0.10) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "Saída atual: \(output.name)" : "Selecionar \(output.name) como saída de áudio")
            }
            if mixer.outputs.isEmpty {
                Text("Nenhuma saída disponível")
                    .font(.system(size: 10)).foregroundStyle(SoundMixStyle.muted)
                    .frame(maxWidth: .infinity, minHeight: 55)
            }
            if let error = mixer.outputSelectionError {
                Text(error).font(.system(size: 9)).foregroundStyle(.red).padding(7)
            }
        }
        .padding(4)
        .softSurface(radius: 15)
    }
}

struct SceneRow: View {
    @EnvironmentObject private var mixer: MixerModel
    let scene: MixScene
    var body: some View {
        Button { mixer.apply(scene) } label: {
            HStack(spacing: 10) {
                SymbolTile(symbol: scene.symbol, tint: scene.tint, size: 31)
                VStack(alignment: .leading, spacing: 3) {
                    Text(scene.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(SoundMixStyle.ink)
                    Text(scene.subtitle).font(.system(size: 9)).foregroundStyle(SoundMixStyle.muted)
                }
                Spacer()
                Image(systemName: mixer.selectedSceneID == scene.id ? "checkmark" : "arrow.right")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(SoundMixStyle.violet)
            }
            .padding(.horizontal, 10)
            .frame(height: 53)
            .softSurface(radius: 13)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsPanel: View {
    @State private var launchAtLogin = true
    @State private var smoothVolume = false

    var body: some View {
        VStack(spacing: 0) {
            setting("Iniciar com o sistema", detail: "Abrir o Sound Mix ao iniciar a sessão", value: $launchAtLogin)
            Divider()
            setting("Suavizar alterações de volume", detail: "Transições mais agradáveis para os ouvidos", value: $smoothVolume)
        }
        .padding(.horizontal, 20)
        .softSurface(radius: 16)
    }

    private func setting(_ title: String, detail: String, value: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(SoundMixStyle.ink)
                Text(detail).font(.system(size: 10)).foregroundStyle(SoundMixStyle.muted)
            }
            Spacer()
            Toggle(title, isOn: value).labelsHidden().tint(SoundMixStyle.violet)
        }
        .frame(height: 73)
    }
}

#Preview {
    MainWindowView().environmentObject(MixerModel())
}
