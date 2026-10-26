import AppKit
import SwiftUI

final class SoundMixAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else { return }
        NSApplication.shared.applicationIconImage = icon
    }
}

@main
struct SoundMixApp: App {
    @NSApplicationDelegateAdaptor(SoundMixAppDelegate.self) private var appDelegate
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @StateObject private var mixer = MixerModel()
    @StateObject private var spotify = SpotifyPlayback()

    var body: some Scene {
        MenuBarExtra("Sound Mix", systemImage: "waveform") {
            MenuBarPanel()
                .environmentObject(mixer)
                .environmentObject(spotify)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
        }
        .menuBarExtraStyle(.window)

        Window("Sound Mix", id: "main") {
            MainWindowView()
                .environmentObject(mixer)
                .environmentObject(spotify)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1160, height: 760)
    }
}
