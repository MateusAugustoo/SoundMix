import SwiftUI
import Combine
import CoreAudio

struct AudioOutput: Identifiable {
    let id: String
    let name: String
    let shortName: String
    let detail: String
    let symbol: String
}

struct MixScene: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let tint: Color
}

struct SceneAppChoice: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct SceneSettings: Codable {
    var masterVolume: Double
    var otherAppsVolume: Double
    var featuredApps: [SceneAppChoice]

    func volume(for appID: String) -> Double {
        featuredApps.contains(where: { $0.id == appID }) ? 100 : otherAppsVolume
    }
}

final class MixerModel: ObservableObject {
    private let systemOutput = SystemOutputAudio()
    private let audioApplications = AudioApplications()
    private let appAudio = PerAppAudioControl()
    @Published private(set) var masterVolume: Double = 0
    @Published private(set) var previousMasterVolume: Double = 50
    @Published private(set) var masterMuted = false
    @Published private(set) var canControlMasterVolume = false
    @Published private(set) var canControlMasterMute = false
    @Published private(set) var outputConnected = false
    @Published private(set) var selectedOutputID = ""
    @Published private(set) var outputName = "Detectando saída de áudio…"
    @Published private(set) var outputs: [AudioOutput] = []
    @Published private(set) var outputSelectionError: String?
    @Published var selectedSceneID: String?
    @Published private(set) var sceneError: String?
    @Published private(set) var apps: [AudioApplication] = []
    @Published private(set) var appVolumes: [String: Double] = [:]
    @Published private(set) var appErrors: [String: String] = [:]
    @Published private(set) var sceneSettings: [String: SceneSettings] = [:]
    private var previousAppVolumes: [String: Double] = [:]
    private var sceneBaseline: (outputID: String, masterVolume: Double, muted: Bool, appVolumes: [String: Double])?
    private let sceneSettingsKey = "sceneSettings.v1"

    let scenes: [MixScene] = [
        .init(id: "focus", name: "Foco", subtitle: "Menos distrações", symbol: "sparkles", tint: .purple),
        .init(id: "meeting", name: "Reunião", subtitle: "Chamadas em destaque", symbol: "headphones", tint: .blue),
        .init(id: "relax", name: "Descanso", subtitle: "Som mais suave", symbol: "waveform", tint: .orange)
    ]

    init() {
        let defaults: [String: SceneSettings] = [
            "focus": .init(masterVolume: 64, otherAppsVolume: 65, featuredApps: []),
            "meeting": .init(masterVolume: 72, otherAppsVolume: 35, featuredApps: []),
            "relax": .init(masterVolume: 38, otherAppsVolume: 80, featuredApps: [])
        ]
        let saved = UserDefaults.standard.data(forKey: sceneSettingsKey)
            .flatMap { try? JSONDecoder().decode([String: SceneSettings].self, from: $0) } ?? [:]
        sceneSettings = defaults.merging(saved) { _, saved in saved }
        systemOutput.onChange = { [weak self] snapshot in
            self?.applyOutputSnapshot(snapshot)
        }
        audioApplications.onChange = { [weak self] applications in
            self?.applyApplications(applications)
        }
        systemOutput.start()
        audioApplications.start()
    }

    var selectedOutput: AudioOutput {
        outputs.first(where: { $0.id == selectedOutputID }) ?? AudioOutput(
            id: selectedOutputID,
            name: outputName,
            shortName: outputName,
            detail: outputConnected
                ? (canControlMasterVolume ? "Saída padrão do macOS" : "Volume não ajustável neste dispositivo")
                : "Nenhuma saída disponível",
            symbol: "speaker.wave.2"
        )
    }

    func selectOutput(_ id: String) {
        guard let deviceID = UInt32(id), id != selectedOutputID else { return }
        outputSelectionError = nil
        if !systemOutput.selectOutput(AudioObjectID(deviceID)) {
            outputSelectionError = "Não foi possível selecionar esta saída. Verifique se o dispositivo continua conectado."
        }
    }

    var isMasterSilent: Bool {
        masterMuted || masterVolume < 0.5
    }

    var canToggleMasterMute: Bool {
        canControlMasterMute || canControlMasterVolume
    }

    var masterBinding: Binding<Double> {
        Binding(
            get: { self.masterVolume },
            set: { value in
                guard self.canControlMasterVolume else { return }
                self.deactivateScene()
                _ = self.systemOutput.setVolume(value)
            }
        )
    }

    func volumeBinding(for appID: String) -> Binding<Double> {
        Binding(
            get: { self.appVolumes[appID] ?? 100 },
            set: { self.setAppVolume($0, for: appID) }
        )
    }

    func toggleAppMute(_ appID: String) {
        let current = appVolumes[appID] ?? 100
        setAppVolume(current < 0.5 ? (previousAppVolumes[appID] ?? 100) : 0, for: appID)
    }

    @discardableResult
    private func setAppVolume(_ value: Double, for appID: String, preserveScene: Bool = false) -> Bool {
        guard let app = apps.first(where: { $0.id == appID }), outputConnected else { return false }
        if !preserveScene { deactivateScene() }
        let volume = min(max(value, 0), 100)
        let previous = appVolumes[appID] ?? 100
        appVolumes[appID] = volume
        let succeeded: Bool
        do {
            try appAudio.setVolume(volume, for: app, outputDeviceID: AudioObjectID(UInt32(selectedOutputID) ?? 0))
            if volume > 0.5 { previousAppVolumes[appID] = volume }
            appErrors.removeValue(forKey: appID)
            succeeded = true
        } catch {
            appVolumes[appID] = 100
            appErrors[appID] = error.localizedDescription
            if previous < 100 { previousAppVolumes[appID] = previous }
            succeeded = false
        }
        return succeeded
    }

    func toggleMasterMute() {
        deactivateScene()
        if canControlMasterMute {
            _ = systemOutput.setMuted(!masterMuted)
        } else if canControlMasterVolume {
            _ = systemOutput.setVolume(isMasterSilent ? previousMasterVolume : 0)
        }
    }

    func settings(for scene: MixScene) -> SceneSettings {
        sceneSettings[scene.id] ?? .init(masterVolume: 50, otherAppsVolume: 50, featuredApps: [])
    }

    func save(_ settings: SceneSettings, for scene: MixScene) {
        var cleaned = settings
        cleaned.masterVolume = min(max(settings.masterVolume, 0), 100)
        cleaned.otherAppsVolume = min(max(settings.otherAppsVolume, 0), 100)
        cleaned.featuredApps = Array(Dictionary(settings.featuredApps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        sceneSettings[scene.id] = cleaned
        if let data = try? JSONEncoder().encode(sceneSettings) {
            UserDefaults.standard.set(data, forKey: sceneSettingsKey)
        }
        if selectedSceneID == scene.id { apply(scene) }
    }

    func deactivateScene(restoreMaster: Bool = true) {
        guard selectedSceneID != nil, let baseline = sceneBaseline else {
            selectedSceneID = nil
            sceneBaseline = nil
            sceneError = nil
            return
        }
        selectedSceneID = nil
        sceneBaseline = nil
        sceneError = nil
        if restoreMaster && baseline.outputID == selectedOutputID {
            if canControlMasterVolume { _ = systemOutput.setVolume(baseline.masterVolume) }
            if canControlMasterMute { _ = systemOutput.setMuted(baseline.muted) }
        }
        for (appID, volume) in baseline.appVolumes {
            if apps.contains(where: { $0.id == appID }) {
                setAppVolume(volume, for: appID, preserveScene: true)
            } else {
                appVolumes[appID] = volume
            }
        }
    }

    func apply(_ scene: MixScene) {
        let settings = settings(for: scene)
        guard outputConnected else {
            sceneError = "Conecte uma saída de áudio para aplicar a cena."
            return
        }
        guard canControlMasterVolume || !apps.isEmpty else {
            sceneError = "Esta saída não permite ajustar o volume e não há aplicativos de áudio ativos."
            return
        }

        if sceneBaseline == nil {
            sceneBaseline = (selectedOutputID, masterVolume, masterMuted, appVolumes)
        }
        for app in apps where sceneBaseline?.appVolumes[app.id] == nil {
            sceneBaseline?.appVolumes[app.id] = appVolumes[app.id] ?? 100
        }
        selectedSceneID = scene.id
        sceneError = nil
        let masterSucceeded: Bool
        if canControlMasterVolume {
            masterSucceeded = systemOutput.setVolume(settings.masterVolume)
        } else if masterMuted {
            masterSucceeded = canControlMasterMute && systemOutput.setMuted(false)
        } else {
            masterSucceeded = true
        }
        let failedApps = apps.reduce(into: 0) { count, app in
            let volume = settings.volume(for: app.id)
            if !setAppVolume(volume, for: app.id, preserveScene: true) { count += 1 }
        }

        if !masterSucceeded || failedApps > 0 {
            sceneError = "A cena foi aplicada parcialmente. Verifique a saída e as permissões de áudio dos aplicativos."
        }
    }

    private func applyOutputSnapshot(_ snapshot: SystemOutputSnapshot) {
        let outputChanged = selectedOutputID != (snapshot.isConnected ? String(snapshot.deviceID) : "")
        let sceneToReapply = outputChanged ? scenes.first(where: { $0.id == selectedSceneID }) : nil
        if outputChanged {
            selectedSceneID = nil
            sceneError = nil
            if snapshot.isConnected, sceneBaseline != nil {
                sceneBaseline?.outputID = String(snapshot.deviceID)
                sceneBaseline?.masterVolume = snapshot.volume
                sceneBaseline?.muted = snapshot.isMuted
            } else {
                if let baseline = sceneBaseline {
                    for (appID, volume) in baseline.appVolumes { appVolumes[appID] = volume }
                }
                sceneBaseline = nil
            }
        } else if let selectedSceneID,
                  let scene = scenes.first(where: { $0.id == selectedSceneID }),
                  (snapshot.isMuted || (snapshot.canSetVolume && abs(snapshot.volume - settings(for: scene).masterVolume) > 1)) {
            deactivateScene(restoreMaster: false)
        }
        outputConnected = snapshot.isConnected
        selectedOutputID = snapshot.isConnected ? String(snapshot.deviceID) : ""
        outputName = snapshot.name
        outputs = snapshot.devices.map { device in
            let lowerName = device.name.lowercased()
            let isHeadphone = lowerName.contains("fone") || lowerName.contains("headphone") || lowerName.contains("airpod")
            let detail: String
            let symbol: String
            switch device.transportType {
            case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
                detail = "Bluetooth"
                symbol = "headphones"
            case kAudioDeviceTransportTypeAirPlay:
                detail = "AirPlay"
                symbol = "airplayaudio"
            case kAudioDeviceTransportTypeUSB:
                detail = "USB"
                symbol = isHeadphone ? "headphones" : "speaker.wave.2"
            case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
                detail = "Monitor externo"
                symbol = "display"
            case kAudioDeviceTransportTypeBuiltIn:
                detail = "Integrado ao Mac"
                symbol = isHeadphone ? "headphones" : "speaker.wave.2"
            default:
                detail = "Saída de áudio"
                symbol = isHeadphone ? "headphones" : "speaker.wave.2"
            }
            return AudioOutput(id: String(device.id), name: device.name, shortName: device.name,
                               detail: detail, symbol: symbol)
        }
        if outputChanged { outputSelectionError = nil }
        masterVolume = snapshot.volume
        masterMuted = snapshot.isMuted
        canControlMasterVolume = snapshot.canSetVolume
        canControlMasterMute = snapshot.canSetMute
        if snapshot.volume > 0.5 { previousMasterVolume = snapshot.volume }
        if outputChanged {
            appAudio.stopAll()
            if let sceneToReapply, snapshot.isConnected {
                apply(sceneToReapply)
            } else {
                for app in apps where (appVolumes[app.id] ?? 100) < 100 {
                    setAppVolume(appVolumes[app.id] ?? 100, for: app.id, preserveScene: true)
                }
            }
        }
    }

    private func applyApplications(_ applications: [AudioApplication]) {
        let previousApps = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        let liveIDs = Set(applications.map(\.id))
        for app in apps where !liveIDs.contains(app.id) { appAudio.stop(appID: app.id) }
        apps = applications
        if let scene = scenes.first(where: { $0.id == selectedSceneID }) {
            let settings = settings(for: scene)
            var failed = false
            for app in applications {
                if sceneBaseline?.appVolumes[app.id] == nil {
                    sceneBaseline?.appVolumes[app.id] = appVolumes[app.id] ?? 100
                }
                let target = settings.volume(for: app.id)
                if abs((appVolumes[app.id] ?? 100) - target) > 0.5 || previousApps[app.id]?.processIDs != app.processIDs {
                    if !setAppVolume(target, for: app.id, preserveScene: true) { failed = true }
                }
            }
            if failed {
                sceneError = "Um aplicativo novo não pôde receber os ajustes da cena. Verifique a permissão de áudio."
            }
        } else {
            for app in applications where (appVolumes[app.id] ?? 100) < 100 {
                if previousApps[app.id]?.processIDs != app.processIDs {
                    setAppVolume(appVolumes[app.id] ?? 100, for: app.id, preserveScene: true)
                }
            }
        }
    }
}
