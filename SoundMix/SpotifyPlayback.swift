import AppKit
import Combine
import SwiftUI

/// Controls the installed Spotify app through its AppleScript playback commands.
final class SpotifyPlayback: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isPlaying = false
    @Published private(set) var trackName: String?
    @Published private(set) var artistName: String?
    @Published private(set) var artworkURL: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isBusy = false

    private let queue = DispatchQueue(label: "com.soundmix.spotify")
    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var isRefreshing = false
    private var permissionDenied = false

    var canControl: Bool { isRunning && !isBusy }

    func start() {
        guard timer == nil else { return }
        let notifications = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            let observer = notifications.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            }
            workspaceObservers.append(observer)
        }
        let timer = Timer(timeInterval: 4, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }

    deinit {
        timer?.invalidate()
        let notifications = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers { notifications.removeObserver(observer) }
    }

    func refresh(force: Bool = false) {
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        isRunning = running
        guard running else {
            isPlaying = false
            trackName = nil
            artistName = nil
            artworkURL = nil
            errorMessage = nil
            permissionDenied = false
            return
        }
        guard !isRefreshing && !isBusy && (force || !permissionDenied) else { return }
        isRefreshing = true
        queue.async { [weak self] in
            let script = """
            tell application id "com.spotify.client"
                set playbackState to player state
                if playbackState is stopped then return {"stopped", "", "", ""}
                try
                    set activeTrack to current track
                    set trackTitle to name of activeTrack as text
                    set trackArtist to artist of activeTrack as text
                    set coverURL to ""
                    try
                        set coverURL to artwork url of activeTrack as text
                    end try
                on error
                    set trackTitle to ""
                    set trackArtist to ""
                    set coverURL to ""
                end try
                if playbackState is playing then
                    return {"playing", trackTitle, trackArtist, coverURL}
                else
                    return {"paused", trackTitle, trackArtist, coverURL}
                end if
            end tell
            """
            var scriptError: NSDictionary?
            let result = NSAppleScript(source: script)?.executeAndReturnError(&scriptError)
            let state = result?.atIndex(1)?.stringValue
            let title = result?.atIndex(2)?.stringValue
            let artist = result?.atIndex(3)?.stringValue
            let artwork = result?.atIndex(4)?.stringValue
            let errorCode = scriptError?["NSAppleScriptErrorNumber"] as? Int
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isRefreshing = false
                guard self.isRunning else { return }
                guard !self.isBusy else { return }
                if let state {
                    self.isPlaying = state == "playing"
                    self.trackName = title?.isEmpty == false ? title : nil
                    self.artistName = artist?.isEmpty == false ? artist : nil
                    self.artworkURL = artwork.flatMap { URL(string: $0) }
                    self.errorMessage = nil
                    self.permissionDenied = false
                } else {
                    self.setError(code: errorCode)
                }
            }
        }
    }

    func previous() { send("previous track") }
    func togglePlayback() { send("playpause", togglesPlayback: true) }
    func next() { send("next track") }

    private func send(_ command: String, togglesPlayback: Bool = false) {
        guard canControl else { return }
        let wasPlaying = isPlaying
        if togglesPlayback { isPlaying.toggle() }
        isBusy = true
        errorMessage = nil
        queue.async { [weak self] in
            var scriptError: NSDictionary?
            let result = NSAppleScript(source: "tell application id \"com.spotify.client\" to \(command)")?
                .executeAndReturnError(&scriptError)
            let errorCode = scriptError?["NSAppleScriptErrorNumber"] as? Int
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isBusy = false
                if result == nil {
                    if togglesPlayback { self.isPlaying = wasPlaying }
                    self.setError(code: errorCode)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                        self?.refresh(force: true)
                    }
                }
            }
        }
    }

    private func setError(code: Int?) {
        if code == -1743 {
            permissionDenied = true
            errorMessage = "Permita o Sound Mix em Ajustes do Sistema > Privacidade e Segurança > Automação."
        } else if code == -600 {
            errorMessage = "O Spotify não está respondendo. Tente novamente."
        } else {
            errorMessage = "Não foi possível controlar o Spotify. Tente novamente."
        }
    }
}

struct SpotifyPlayerCard: View {
    @EnvironmentObject private var spotify: SpotifyPlayback
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 3) {
                Text("SPOTIFY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(SoundMixStyle.muted)
                Text(spotify.trackName ?? (spotify.isRunning ? "Nada tocando" : "Spotify fechado"))
                    .font(.system(size: compact ? 11 : 14, weight: .semibold))
                    .foregroundStyle(SoundMixStyle.ink)
                    .lineLimit(1)
                Text(spotify.errorMessage ?? spotify.artistName ?? (spotify.isRunning ? "Controle de reprodução" : "Abra o Spotify para controlar a música"))
                    .font(.system(size: compact ? 9 : 11))
                    .foregroundStyle(spotify.errorMessage == nil ? SoundMixStyle.muted : .red)
                    .lineLimit(compact ? 2 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if spotify.errorMessage != nil {
                Button("Tentar novamente") { spotify.refresh(force: true) }
                    .font(.system(size: 10, weight: .semibold))
                    .soundMixGlassButton()
            } else {
                HStack(spacing: compact ? 3 : 7) {
                    control("backward.end.fill", label: "Música anterior", action: spotify.previous)
                    control(spotify.isPlaying ? "pause.fill" : "play.fill",
                            label: spotify.isPlaying ? "Pausar Spotify" : "Reproduzir Spotify",
                            action: spotify.togglePlayback)
                    control("forward.end.fill", label: "Próxima música", action: spotify.next)
                }
            }
        }
        .padding(compact ? 11 : 16)
        .softSurface(radius: 15)
    }

    private var artwork: some View {
        let size: CGFloat = compact ? 32 : 42
        return ZStack {
            SymbolTile(symbol: "music.note", tint: SoundMixStyle.violet, size: size)
            if let url = spotify.artworkURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipped()
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.25))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(spotify.trackName.map { "Capa de \($0)" } ?? "Spotify")
    }

    private func control(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 12 : 15, weight: .semibold))
                .frame(width: compact ? 26 : 32, height: compact ? 26 : 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(spotify.canControl ? SoundMixStyle.violetDeep : SoundMixStyle.muted)
        .background(SoundMixStyle.selection, in: Circle())
        .disabled(!spotify.canControl)
        .accessibilityLabel(label)
    }
}
