import AppKit
import CoreAudio
import Foundation

struct AudioApplication: Identifiable {
    let id: String
    let name: String
    let icon: NSImage?
    let processIDs: [AudioObjectID]

    var processCount: Int { processIDs.count }

    var detail: String {
        processCount == 1 ? "Usando saída de áudio" : "\(processCount) processos de áudio ativos"
    }
}

/// Lists applications with an active Core Audio output stream.
/// Core Audio reports active streams, which may also contain silence.
final class AudioApplications {
    var onChange: (([AudioApplication]) -> Void)?

    private var timer: Timer?
    private var processListListener: AudioObjectPropertyListenerBlock?
    private var outputListeners: [AudioObjectID: AudioObjectPropertyListenerBlock] = [:]
    private var refreshScheduled = false
    private var lastSignature: [(String, String, [AudioObjectID])] = []

    func start() {
        guard timer == nil else { return }
        var address = property(kAudioHardwarePropertyProcessObjectList)
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.scheduleRefresh() }
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener) == noErr {
            processListListener = listener
        }

        // Reconcile occasionally in case a third-party audio driver misses a notification.
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }

    deinit {
        timer?.invalidate()
        var outputAddress = property(kAudioProcessPropertyIsRunningOutput)
        for (processID, listener) in outputListeners {
            AudioObjectRemovePropertyListenerBlock(processID, &outputAddress, .main, listener)
        }
        if let processListListener {
            var address = property(kAudioHardwarePropertyProcessObjectList)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, processListListener)
        }
    }

    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.refreshScheduled = false
            self?.refresh()
        }
    }

    private func refresh() {
        let objects = processObjects()
        updateOutputListeners(for: objects)
        let activeObjects = objects.filter {
            read($0, property(kAudioProcessPropertyIsRunningOutput), initial: UInt32(0)) == 1
        }
        if activeObjects.isEmpty {
            guard !lastSignature.isEmpty else { return }
            lastSignature = []
            onChange?([])
            return
        }

        let running = NSWorkspace.shared.runningApplications
        let regularApps = running.filter { $0.activationPolicy == .regular }
            .sorted { ($0.bundleIdentifier?.count ?? 0) > ($1.bundleIdentifier?.count ?? 0) }
        var grouped: [String: (name: String, icon: NSImage?, processIDs: [AudioObjectID])] = [:]

        for processID in activeObjects {
            let pid = read(processID, property(kAudioProcessPropertyPID), initial: pid_t(0)) ?? 0
            guard pid > 0, pid != ProcessInfo.processInfo.processIdentifier else { continue }

            let bundleID = readBundleID(processID)
            let processApp = running.first { $0.processIdentifier == pid }
            let matchingApp = bundleID.flatMap { bundleID in
                regularApps.first { app in
                    guard let appBundleID = app.bundleIdentifier else { return false }
                    return bundleID == appBundleID || bundleID.hasPrefix(appBundleID + ".")
                }
            }
            let app = matchingApp ?? processApp
            guard let app, app.activationPolicy != .prohibited else { continue }
            let id = app.bundleIdentifier ?? bundleID ?? "pid:\(pid)"
            let name = app.localizedName ?? bundleID?.components(separatedBy: ".").last ?? "Processo de áudio \(pid)"

            if var existing = grouped[id] {
                existing.processIDs.append(processID)
                grouped[id] = existing
            } else {
                grouped[id] = (name, app.icon, [processID])
            }
        }

        let applications = grouped.map { AudioApplication(id: $0.key, name: $0.value.name, icon: $0.value.icon, processIDs: $0.value.processIDs.sorted()) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let signature = applications.map { ($0.id, $0.name, $0.processIDs) }
        guard !sameSignature(signature, lastSignature) else { return }
        lastSignature = signature
        onChange?(applications)
    }

    private func updateOutputListeners(for objects: [AudioObjectID]) {
        let liveIDs = Set(objects)
        var address = property(kAudioProcessPropertyIsRunningOutput)
        for processID in outputListeners.keys.filter({ !liveIDs.contains($0) }) {
            guard let listener = outputListeners.removeValue(forKey: processID) else { continue }
            AudioObjectRemovePropertyListenerBlock(processID, &address, .main, listener)
        }
        for processID in objects where outputListeners[processID] == nil {
            let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.scheduleRefresh() }
            if AudioObjectAddPropertyListenerBlock(processID, &address, .main, listener) == noErr {
                outputListeners[processID] = listener
            }
        }
    }

    private func sameSignature(_ left: [(String, String, [AudioObjectID])], _ right: [(String, String, [AudioObjectID])]) -> Bool {
        left.count == right.count && zip(left, right).allSatisfy { $0.0 == $0.1 }
    }

    private func processObjects() -> [AudioObjectID] {
        var address = property(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr,
              size > 0 else { return [] }

        var objects = [AudioObjectID](repeating: kAudioObjectUnknown, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let status = objects.withUnsafeMutableBufferPointer { buffer in
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, buffer.baseAddress!)
        }
        guard status == noErr else { return [] }
        return Array(objects.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    private func read<T>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, initial: T) -> T? {
        var address = address
        guard AudioObjectHasProperty(object, &address) else { return nil }
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutableBytes(of: &value) { bytes in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, bytes.baseAddress!)
        }
        return status == noErr && size == MemoryLayout<T>.size ? value : nil
    }

    private func readBundleID(_ object: AudioObjectID) -> String? {
        var address = property(kAudioProcessPropertyBundleID)
        guard AudioObjectHasProperty(object, &address) else { return nil }
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }

    private func property(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
}
