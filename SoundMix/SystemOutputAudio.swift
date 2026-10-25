import CoreAudio
import Foundation

struct SystemAudioDevice: Equatable {
    let id: AudioObjectID
    let name: String
    let transportType: UInt32
}

struct SystemOutputSnapshot: Equatable {
    var deviceID: AudioObjectID = kAudioObjectUnknown
    var name = "Nenhuma saída de áudio"
    var devices: [SystemAudioDevice] = []
    var volume: Double = 0
    var isMuted = false
    var canSetVolume = false
    var canSetMute = false

    var isConnected: Bool { deviceID != kAudioObjectUnknown }
}

/// Reads and controls the macOS default output device. Core Audio callbacks run on the main queue.
final class SystemOutputAudio {
    var onChange: ((SystemOutputSnapshot) -> Void)?

    private let listenerQueue = DispatchQueue.main
    private var currentDeviceID: AudioObjectID = kAudioObjectUnknown
    private var currentSnapshot: SystemOutputSnapshot?
    private var cachedDevices: [SystemAudioDevice] = []
    private var deviceListDirty = true
    private var volumeElements: [AudioObjectPropertyElement] = []
    private var muteElements: [AudioObjectPropertyElement] = []
    private var canSetVolume = false
    private var canSetMute = false
    private var systemListener: AudioObjectPropertyListenerBlock?
    private var deviceListListener: AudioObjectPropertyListenerBlock?
    private var deviceListeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    func start() {
        var address = property(kAudioHardwarePropertyDefaultOutputDevice)
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.refresh() }
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, listenerQueue, listener) == noErr {
            systemListener = listener
        }
        var devicesAddress = property(kAudioHardwarePropertyDevices)
        let devicesListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.deviceListDirty = true
            self?.refresh()
        }
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddress, listenerQueue, devicesListener) == noErr {
            deviceListListener = devicesListener
        }
        refresh()
    }

    deinit {
        removeDeviceListeners()
        if let systemListener {
            var address = property(kAudioHardwarePropertyDefaultOutputDevice)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, listenerQueue, systemListener)
        }
        if let deviceListListener {
            var address = property(kAudioHardwarePropertyDevices)
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, listenerQueue, deviceListListener)
        }
    }

    @discardableResult
    func selectOutput(_ deviceID: AudioObjectID) -> Bool {
        guard currentSnapshot?.devices.contains(where: { $0.id == deviceID }) == true else { return false }
        var address = property(kAudioHardwarePropertyDefaultOutputDevice)
        guard isSettable(AudioObjectID(kAudioObjectSystemObject), address) else { return false }
        var selectedID = deviceID
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                                                UInt32(MemoryLayout<AudioObjectID>.size), &selectedID)
        if status == noErr { refresh() }
        return status == noErr
    }

    @discardableResult
    func setVolume(_ percent: Double) -> Bool {
        guard currentSnapshot?.canSetVolume == true, currentDeviceID != kAudioObjectUnknown else { return false }
        var scalar = Float32(min(max(percent / 100, 0), 1))
        var succeeded = true
        for element in volumeElements {
            var address = property(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput, element: element)
            if AudioObjectSetPropertyData(currentDeviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &scalar) != noErr {
                succeeded = false
            }
        }
        if percent > 0, currentSnapshot?.isMuted == true, currentSnapshot?.canSetMute == true {
            succeeded = setMuted(false) && succeeded
        }
        refresh()
        return succeeded
    }

    @discardableResult
    func setMuted(_ muted: Bool) -> Bool {
        guard currentSnapshot?.canSetMute == true, currentDeviceID != kAudioObjectUnknown else { return false }
        var value: UInt32 = muted ? 1 : 0
        var succeeded = true
        for element in muteElements {
            var address = property(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput, element: element)
            if AudioObjectSetPropertyData(currentDeviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) != noErr {
                succeeded = false
            }
        }
        refresh()
        return succeeded
    }

    private func refresh() {
        let systemAddress = property(kAudioHardwarePropertyDefaultOutputDevice)
        let deviceID: AudioObjectID = read(AudioObjectID(kAudioObjectSystemObject), systemAddress, initial: kAudioObjectUnknown) ?? kAudioObjectUnknown
        let deviceListChanged = deviceListDirty
        if deviceListChanged {
            cachedDevices = availableOutputs()
            deviceListDirty = false
        }
        let devices = cachedDevices.sorted { lhs, rhs in
            if lhs.id == deviceID { return true }
            if rhs.id == deviceID { return false }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        if deviceID != currentDeviceID || deviceListChanged {
            removeDeviceListeners()
            currentDeviceID = deviceID
            configureCurrentDevice()
        }

        guard deviceID != kAudioObjectUnknown else {
            var snapshot = SystemOutputSnapshot()
            snapshot.devices = devices
            publish(snapshot)
            return
        }

        let volumeValues = volumeElements.compactMap {
            read(deviceID, property(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput, element: $0), initial: Float32(0))
        }
        let muteValues = muteElements.compactMap {
            read(deviceID, property(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput, element: $0), initial: UInt32(0))
        }

        var snapshot = SystemOutputSnapshot()
        snapshot.deviceID = deviceID
        snapshot.name = devices.first(where: { $0.id == deviceID })?.name ?? readName(deviceID) ?? "Saída de áudio"
        snapshot.devices = devices
        snapshot.volume = volumeValues.isEmpty ? 0 : Double(volumeValues.reduce(0, +)) / Double(volumeValues.count) * 100
        snapshot.isMuted = !muteValues.isEmpty && muteValues.allSatisfy { $0 != 0 }
        snapshot.canSetVolume = canSetVolume
        snapshot.canSetMute = canSetMute
        publish(snapshot)
    }

    private func configureCurrentDevice() {
        volumeElements = []
        muteElements = []
        canSetVolume = false
        canSetMute = false
        guard currentDeviceID != kAudioObjectUnknown else { return }

        let deviceID = currentDeviceID
        let mainVolume = property(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput)
        let channelVolumes = [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)]
            .map { property(kAudioDevicePropertyVolumeScalar, scope: kAudioDevicePropertyScopeOutput, element: $0) }
            .filter { read(deviceID, $0, initial: Float32(0)) != nil }
        let volumeAddresses: [AudioObjectPropertyAddress]
        if read(deviceID, mainVolume, initial: Float32(0)) != nil, isSettable(deviceID, mainVolume) {
            volumeAddresses = [mainVolume]
        } else if !channelVolumes.isEmpty, channelVolumes.allSatisfy({ isSettable(deviceID, $0) }) {
            volumeAddresses = channelVolumes
        } else if read(deviceID, mainVolume, initial: Float32(0)) != nil {
            volumeAddresses = [mainVolume]
        } else {
            volumeAddresses = channelVolumes
        }
        volumeElements = volumeAddresses.map(\.mElement)
        canSetVolume = !volumeAddresses.isEmpty && volumeAddresses.allSatisfy { isSettable(deviceID, $0) }

        let mainMute = property(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        let channelMutes = [AudioObjectPropertyElement(1), AudioObjectPropertyElement(2)]
            .map { property(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput, element: $0) }
            .filter { read(deviceID, $0, initial: UInt32(0)) != nil }
        let muteAddresses: [AudioObjectPropertyAddress]
        if read(deviceID, mainMute, initial: UInt32(0)) != nil, isSettable(deviceID, mainMute) {
            muteAddresses = [mainMute]
        } else if !channelMutes.isEmpty, channelMutes.allSatisfy({ isSettable(deviceID, $0) }) {
            muteAddresses = channelMutes
        } else if read(deviceID, mainMute, initial: UInt32(0)) != nil {
            muteAddresses = [mainMute]
        } else {
            muteAddresses = channelMutes
        }
        muteElements = muteAddresses.map(\.mElement)
        canSetMute = !muteAddresses.isEmpty && muteAddresses.allSatisfy { isSettable(deviceID, $0) }

        for address in volumeAddresses + muteAddresses { addDeviceListener(deviceID, address) }
    }

    private func publish(_ snapshot: SystemOutputSnapshot) {
        guard snapshot != currentSnapshot else { return }
        currentSnapshot = snapshot
        onChange?(snapshot)
    }

    private func availableOutputs() -> [SystemAudioDevice] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        return readIDs(system, property(kAudioHardwarePropertyDevices))
            .filter { deviceID in
                let alive = read(deviceID, property(kAudioDevicePropertyDeviceIsAlive), initial: UInt32(1)) ?? 1
                let hidden = read(deviceID, property(kAudioDevicePropertyIsHidden), initial: UInt32(0)) ?? 0
                let canBeDefault = read(deviceID, property(kAudioDevicePropertyDeviceCanBeDefaultDevice), initial: UInt32(1)) ?? 1
                let streams = readIDs(deviceID, property(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput))
                return alive != 0 && hidden == 0 && canBeDefault != 0 && !streams.isEmpty
            }
            .map { deviceID in
                SystemAudioDevice(
                    id: deviceID,
                    name: readName(deviceID) ?? "Saída de áudio",
                    transportType: read(deviceID, property(kAudioDevicePropertyTransportType), initial: UInt32(0)) ?? 0
                )
            }
    }

    private func readIDs(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> [AudioObjectID] {
        var address = address
        var byteCount: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &byteCount) == noErr,
              byteCount >= UInt32(MemoryLayout<AudioObjectID>.size) else { return [] }
        var ids = [AudioObjectID](repeating: kAudioObjectUnknown,
                                  count: Int(byteCount) / MemoryLayout<AudioObjectID>.size)
        let status = ids.withUnsafeMutableBufferPointer { buffer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &byteCount, buffer.baseAddress!)
        }
        guard status == noErr else { return [] }
        return Array(ids.prefix(Int(byteCount) / MemoryLayout<AudioObjectID>.size))
    }

    private func addDeviceListener(_ deviceID: AudioObjectID, _ address: AudioObjectPropertyAddress) {
        var address = address
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.refresh() }
        if AudioObjectAddPropertyListenerBlock(deviceID, &address, listenerQueue, listener) == noErr {
            deviceListeners.append((address, listener))
        }
    }

    private func removeDeviceListeners() {
        for (storedAddress, listener) in deviceListeners {
            var address = storedAddress
            AudioObjectRemovePropertyListenerBlock(currentDeviceID, &address, listenerQueue, listener)
        }
        deviceListeners.removeAll()
    }

    private func property(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    private func read<T>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, initial: T) -> T? {
        var address = address
        guard AudioObjectHasProperty(object, &address) else { return nil }
        var result = initial
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutableBytes(of: &result) { bytes in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, bytes.baseAddress!)
        }
        guard status == noErr, size == MemoryLayout<T>.size else { return nil }
        return result
    }

    private func readName(_ deviceID: AudioObjectID) -> String? {
        var address = property(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    private func isSettable(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(object, &address, &settable) == noErr && settable.boolValue
    }
}
