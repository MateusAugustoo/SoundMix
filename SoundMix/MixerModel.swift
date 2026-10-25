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
    let description: String
    let symbol: String
    let tint: Color
    let masterVolume: Double
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
    @Published private(set) var apps: [AudioApplication] = []
    @Published private(set) var appVolumes: [String: Double] = [:]
    @Published private(set) var appErrors: [String: String] = [:]
    private var previousAppVolumes: [String: Double] = [:]

    let scenes: [MixScene] = [
        .init(id: "focus", name: "Foco", subtitle: "Tudo no seu ritmo", description: "Volume geral equilibrado para trabalhar.", symbol: "sparkles", tint: .purple, masterVolume: 64),
        .init(id: "meeting", name: "Reunião", subtitle: "Vozes em primeiro plano", description: "Volume geral para acompanhar chamadas.", symbol: "headphones", tint: .blue, masterVolume: 72),
        .init(id: "relax", name: "Descanso", subtitle: "Um momento para você", description: "Volume geral mais suave.", symbol: "waveform", tint: .orange, masterVolume: 38)
    ]

    init() {
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
                _ = self.systemOutput.setVolume(value)
                self.selectedSceneID = nil
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

    private func setAppVolume(_ value: Double, for appID: String) {
        guard let app = apps.first(where: { $0.id == appID }), outputConnected else { return }
        let volume = min(max(value, 0), 100)
        let previous = appVolumes[appID] ?? 100
        appVolumes[appID] = volume
        do {
            try appAudio.setVolume(volume, for: app, outputDeviceID: AudioObjectID(UInt32(selectedOutputID) ?? 0))
            if volume > 0.5 { previousAppVolumes[appID] = volume }
            appErrors.removeValue(forKey: appID)
        } catch {
            appVolumes[appID] = 100
            appErrors[appID] = error.localizedDescription
            if previous < 100 { previousAppVolumes[appID] = previous }
        }
        selectedSceneID = nil
    }

    func toggleMasterMute() {
        if canControlMasterMute {
            _ = systemOutput.setMuted(!masterMuted)
        } else if canControlMasterVolume {
            _ = systemOutput.setVolume(isMasterSilent ? previousMasterVolume : 0)
        }
        selectedSceneID = nil
    }

    func apply(_ scene: MixScene) {
        if canControlMasterVolume { _ = systemOutput.setVolume(scene.masterVolume) }
        selectedSceneID = scene.id
    }

    private func applyOutputSnapshot(_ snapshot: SystemOutputSnapshot) {
        let outputChanged = selectedOutputID != (snapshot.isConnected ? String(snapshot.deviceID) : "")
        if outputChanged {
            selectedSceneID = nil
        } else if let selectedSceneID,
                  let scene = scenes.first(where: { $0.id == selectedSceneID }),
                  abs(snapshot.volume - scene.masterVolume) > 1 {
            self.selectedSceneID = nil
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
            for app in apps where (appVolumes[app.id] ?? 100) < 100 {
                setAppVolume(appVolumes[app.id] ?? 100, for: app.id)
            }
        }
    }

    private func applyApplications(_ applications: [AudioApplication]) {
        let previousApps = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        let liveIDs = Set(applications.map(\.id))
        for app in apps where !liveIDs.contains(app.id) { appAudio.stop(appID: app.id) }
        apps = applications
        for app in applications where (appVolumes[app.id] ?? 100) < 100 {
            if previousApps[app.id]?.processIDs != app.processIDs {
                setAppVolume(appVolumes[app.id] ?? 100, for: app.id)
            }
        }
    }
}
