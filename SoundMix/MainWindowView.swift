import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

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
    @State private var editingScene: MixScene?

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
                .background(SoundMixStyle.contentTint)
            }
        }
        .frame(minWidth: 1040, minHeight: 700)
        .sheet(item: $editingScene) { scene in
            SceneEditorView(scene: scene, settings: mixer.settings(for: scene))
                .environmentObject(mixer)
        }
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
        .background(SoundMixStyle.sidebarTint)
        .overlay(alignment: .trailing) { Rectangle().fill(SoundMixStyle.separator).frame(width: 1) }
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
            .background(page == destination ? SoundMixStyle.selection : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if page == destination {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(SoundMixStyle.selectionLine, lineWidth: 1)
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
        .background(SoundMixStyle.toolbarTint)
        .overlay(alignment: .bottom) { Rectangle().fill(SoundMixStyle.separator).frame(height: 1) }
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
                        if let sceneError = mixer.sceneError {
                            Text(sceneError)
                                .font(.system(size: 10))
                                .foregroundStyle(.red)
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
                    VStack(alignment: .leading, spacing: 12) {
                            SymbolTile(symbol: scene.symbol, tint: scene.tint, size: 43)
                            Spacer()
                            Text(scene.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(SoundMixStyle.ink)
                            Text(sceneSummary(scene)).font(.system(size: 11)).foregroundStyle(SoundMixStyle.muted)
                            HStack {
                                Button(mixer.selectedSceneID == scene.id ? "Desativar cena" : "Aplicar cena") {
                                    if mixer.selectedSceneID == scene.id { mixer.deactivateScene() }
                                    else { mixer.apply(scene) }
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .soundMixGlassButton()
                                Spacer()
                                Button("Editar") { editingScene = scene }
                                    .font(.system(size: 11, weight: .semibold))
                                    .soundMixGlassButton()
                            }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, minHeight: 212, alignment: .leading)
                    .softSurface(radius: 17)
                    .overlay {
                        RoundedRectangle(cornerRadius: 17)
                            .strokeBorder(SoundMixStyle.violet.opacity(mixer.selectedSceneID == scene.id ? 0.6 : 0), lineWidth: 1.5)
                    }
                }
            }
            if let sceneError = mixer.sceneError {
                Text(sceneError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            Text("Apps em destaque ficam em 100%. Os demais usam o nível escolhido. Desativar restaura o mix anterior. O controle individual pode pedir permissão do macOS.")
                .font(.system(size: 11)).foregroundStyle(SoundMixStyle.muted)
        }
        .padding(.top, 40)
    }

    private func sceneSummary(_ scene: MixScene) -> String {
        let settings = mixer.settings(for: scene)
        let count = settings.featuredApps.count
        return "Geral \(Int(settings.masterVolume))% · Demais \(Int(settings.otherAppsVolume))% · \(count) \(count == 1 ? "app" : "apps") em destaque"
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
                .fill(RadialGradient(colors: [SoundMixStyle.violet.opacity(0.23), SoundMixStyle.cardGlow], center: .bottomTrailing, startRadius: 10, endRadius: 380))
        }
        .soundMixGlassCard(radius: 19)
        .overlay { RoundedRectangle(cornerRadius: 19).strokeBorder(SoundMixStyle.selectionLine, lineWidth: 1) }
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
                    if app.id != apps.last?.id { Rectangle().fill(SoundMixStyle.separator).frame(height: 1) }
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
        .background(SoundMixStyle.iconBackground, in: RoundedRectangle(cornerRadius: size * 0.25))
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
        Button {
            if mixer.selectedSceneID == scene.id { mixer.deactivateScene() }
            else { mixer.apply(scene) }
        } label: {
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

private struct SceneEditorView: View {
    @EnvironmentObject private var mixer: MixerModel
    @Environment(\.dismiss) private var dismiss
    let scene: MixScene
    @State private var settings: SceneSettings
    @State private var availableApps: [SceneAppChoice] = []

    init(scene: MixScene, settings: SceneSettings) {
        self.scene = scene
        _settings = State(initialValue: settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                SymbolTile(symbol: scene.symbol, tint: scene.tint, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Editar \(scene.name)").font(.system(size: 21, weight: .bold)).foregroundStyle(SoundMixStyle.ink)
                    Text("Escolha os apps que ficam em destaque.").font(.system(size: 12)).foregroundStyle(SoundMixStyle.muted)
                }
                Spacer()
            }

            volumeControl("Volume geral", value: $settings.masterVolume)
            volumeControl("Demais aplicativos", value: $settings.otherAppsVolume)

            HStack {
                Text("APPS EM DESTAQUE")
                    .font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(SoundMixStyle.muted)
                Spacer()
                Button("Escolher app instalado…", action: chooseInstalledApp)
                    .font(.system(size: 11, weight: .semibold))
                    .soundMixGlassButton()
            }
            Text("Selecionados em 100% quando emitirem áudio. Escolha entre os apps abertos ou adicione um app instalado.")
                .font(.system(size: 11)).foregroundStyle(SoundMixStyle.muted)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(availableApps) { app in
                        let selected = settings.featuredApps.contains(where: { $0.id == app.id })
                        Button { toggle(app) } label: {
                            HStack(spacing: 10) {
                                Image(nsImage: icon(for: app))
                                    .resizable().scaledToFit().frame(width: 25, height: 25)
                                Text(app.name).font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(SoundMixStyle.ink)
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17))
                                    .foregroundStyle(selected ? SoundMixStyle.violet : SoundMixStyle.muted)
                            }
                            .padding(.horizontal, 10).frame(height: 40)
                            .background(selected ? SoundMixStyle.violet.opacity(0.1) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(app.name), \(selected ? "em destaque" : "fora do destaque")")
                    }
                }
                .padding(5)
            }
            .frame(height: 180)
            .softSurface(radius: 12)

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }.soundMixGlassButton()
                Button("Salvar cena") {
                    mixer.save(settings, for: scene)
                    dismiss()
                }
                .soundMixGlassButton()
                .tint(SoundMixStyle.violet)
            }
        }
        .padding(25)
        .frame(width: 540)
        .background(SoundMixStyle.contentTint)
        .onAppear(perform: refreshAvailableApps)
    }

    private func volumeControl(_ title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SoundMixStyle.ink).frame(width: 125, alignment: .leading)
            Slider(value: value, in: 0...100, step: 1).tint(SoundMixStyle.violet)
            Text("\(Int(value.wrappedValue))%")
                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .foregroundStyle(SoundMixStyle.violetDeep).frame(width: 36, alignment: .trailing)
        }
    }

    private func refreshAvailableApps() {
        let open = NSWorkspace.shared.runningApplications.compactMap { app -> SceneAppChoice? in
            guard app.activationPolicy == .regular, let id = app.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier else { return nil }
            return SceneAppChoice(id: id, name: app.localizedName ?? id)
        }
        let active = mixer.apps.filter { !$0.id.hasPrefix("pid:") }
            .map { SceneAppChoice(id: $0.id, name: $0.name) }
        availableApps = Array(Dictionary((settings.featuredApps + active + open).map { ($0.id, $0) },
                                         uniquingKeysWith: { first, _ in first }).values)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func toggle(_ app: SceneAppChoice) {
        if settings.featuredApps.contains(where: { $0.id == app.id }) {
            settings.featuredApps.removeAll { $0.id == app.id }
        } else {
            settings.featuredApps.append(app)
        }
    }

    private func icon(for app: SceneAppChoice) -> NSImage {
        if let active = mixer.apps.first(where: { $0.id == app.id }), let icon = active.icon { return icon }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.id) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }

    private func chooseInstalledApp() {
        let panel = NSOpenPanel()
        panel.prompt = "Adicionar"
        panel.message = "Escolha um aplicativo para incluir na cena"
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            guard response == .OK, let url = panel.url,
                  let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            let choice = SceneAppChoice(id: id, name: name)
            if !availableApps.contains(where: { $0.id == id }) { availableApps.append(choice) }
            if !settings.featuredApps.contains(where: { $0.id == id }) { settings.featuredApps.append(choice) }
            availableApps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}

private struct AppearanceSelector: View {
    @Binding var selection: String
    @State private var hoveredMode: AppearanceMode?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppearanceMode.allCases) { mode in
                let isSelected = selection == mode.rawValue

                Button {
                    selection = mode.rawValue
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 12, weight: .medium))
                        Text(mode.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? SoundMixStyle.violetDeep : SoundMixStyle.muted)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [SoundMixStyle.violet.opacity(0.18), SoundMixStyle.selection],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(SoundMixStyle.selectionLine, lineWidth: 1)
                                }
                        } else if hoveredMode == mode {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(SoundMixStyle.selection.opacity(0.45))
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    if isHovering {
                        hoveredMode = mode
                    } else if hoveredMode == mode {
                        hoveredMode = nil
                    }
                }
                .accessibilityLabel(mode.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .frame(width: 270)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .background(SoundMixStyle.surfaceTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(SoundMixStyle.line, lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.18), value: selection)
        .animation(.easeInOut(duration: 0.18), value: hoveredMode)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Aparência")
    }
}

private struct SoundMixToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 14) {
                configuration.label
                Spacer()
                Text(configuration.isOn ? "Ligado" : "Desligado")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(configuration.isOn ? SoundMixStyle.violetDeep : SoundMixStyle.muted)
                    .frame(width: 58, alignment: .trailing)
                    .accessibilityHidden(true)

                Capsule()
                    .fill(configuration.isOn ? SoundMixStyle.violet : SoundMixStyle.switchOff)
                    .overlay {
                        Capsule()
                            .strokeBorder(configuration.isOn ? SoundMixStyle.violetDeep.opacity(0.55) : SoundMixStyle.switchOffLine, lineWidth: 1)
                    }
                    .overlay {
                        Circle()
                            .fill(configuration.isOn ? SoundMixStyle.switchThumbOn : SoundMixStyle.switchThumbOff)
                            .frame(width: 23, height: 23)
                            .shadow(color: SoundMixStyle.shadow, radius: 3, y: 1)
                            .offset(x: configuration.isOn ? 12 : -12)
                    }
                    .frame(width: 56, height: 31)
                    .shadow(color: SoundMixStyle.violet.opacity(configuration.isOn ? 0.24 : 0), radius: 6)
                    .accessibilityHidden(true)
            }
            .frame(height: 73)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(configuration.isOn ? "Ligado" : "Desligado")
        .animation(.easeInOut(duration: 0.18), value: configuration.isOn)
    }
}

private struct SettingsPanel: View {
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @State private var launchAtLoginStatus: SMAppService.Status = .notRegistered
    @State private var launchAtLoginError: String?
    @State private var smoothVolume = false

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { launchAtLoginStatus == .enabled || launchAtLoginStatus == .requiresApproval },
            set: { updateLaunchAtLogin($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Aparência").font(.system(size: 12, weight: .semibold)).foregroundStyle(SoundMixStyle.ink)
                    Text("Escolha o tema do Sound Mix").font(.system(size: 10)).foregroundStyle(SoundMixStyle.muted)
                }
                Spacer()
                AppearanceSelector(selection: $appearanceMode)
            }
            .frame(height: 73)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                setting("Iniciar com o sistema", detail: "Abrir o Sound Mix ao iniciar a sessão", value: launchAtLogin)

                if launchAtLoginStatus == .requiresApproval {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                        Text("Autorize o Sound Mix nos itens de início de sessão.")
                        Button("Abrir Ajustes do Sistema") {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                        .buttonStyle(.plain)
                        .fontWeight(.semibold)
                        .foregroundStyle(SoundMixStyle.violetDeep)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(SoundMixStyle.muted)
                    .padding(.bottom, 14)
                }

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .padding(.bottom, 14)
                }
            }
            Divider()
            setting("Suavizar alterações de volume", detail: "Transições mais agradáveis para os ouvidos", value: $smoothVolume)
        }
        .padding(.horizontal, 20)
        .softSurface(radius: 16)
        .onAppear(perform: refreshLaunchAtLogin)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshLaunchAtLogin()
        }
    }

    private func refreshLaunchAtLogin() {
        launchAtLoginStatus = SMAppService.mainApp.status
        launchAtLoginError = nil
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        var operationError: Error?

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            operationError = error
        }

        refreshLaunchAtLogin()
        let isRegistered = launchAtLoginStatus == .enabled || launchAtLoginStatus == .requiresApproval
        if let operationError, isRegistered != enabled {
            launchAtLoginError = "Não foi possível alterar o início automático: \(operationError.localizedDescription)"
        } else {
            launchAtLoginError = nil
        }
    }

    private func setting(_ title: String, detail: String, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(SoundMixStyle.ink)
                Text(detail).font(.system(size: 10)).foregroundStyle(SoundMixStyle.muted)
            }
        }
        .toggleStyle(SoundMixToggleStyle())
    }
}

#Preview {
    MainWindowView().environmentObject(MixerModel())
}
