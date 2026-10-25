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
    @StateObject private var mixer = MixerModel()

    var body: some Scene {
        MenuBarExtra("Sound Mix", systemImage: "waveform") {
            MenuBarPanel()
                .environmentObject(mixer)
        }
        .menuBarExtraStyle(.window)

        Window("Sound Mix", id: "main") {
            MainWindowView()
                .environmentObject(mixer)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1160, height: 760)
    }
}
