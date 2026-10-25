import AudioToolbox
import CoreAudio
import Foundation

enum PerAppAudioError: LocalizedError {
    case noOutput
    case unsupportedFormat
    case coreAudio(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noOutput: "Nenhuma saída de áudio disponível."
        case .unsupportedFormat: "O formato desta saída ainda não é compatível com o controle individual."
        case .coreAudio: "Não foi possível iniciar o controle. Verifique a permissão de áudio do sistema."
        }
    }
}

/// Captures one application's output through a private tap and plays it back through
/// an aggregate device using the physical output as its clock. The tap only mutes
/// the original signal while our IOProc is reading it.
final class PerAppAudioControl {
    private final class GainBox {
        let storage: OpaquePointer

        init?(_ gain: Float) {
            guard let storage = SoundMixGainCreate(gain) else { return nil }
            self.storage = storage
        }

        deinit { SoundMixGainDestroy(storage) }
    }

    private final class Route {
        let tapID: AudioObjectID
        let aggregateID: AudioObjectID
        let ioProcID: AudioDeviceIOProcID
        let outputDeviceID: AudioObjectID
        let processIDs: [AudioObjectID]
        let gainBox: GainBox

        init(tapID: AudioObjectID, aggregateID: AudioObjectID, ioProcID: AudioDeviceIOProcID,
             outputDeviceID: AudioObjectID, processIDs: [AudioObjectID], gainBox: GainBox) {
            self.tapID = tapID
            self.aggregateID = aggregateID
            self.ioProcID = ioProcID
            self.outputDeviceID = outputDeviceID
            self.processIDs = processIDs
            self.gainBox = gainBox
        }

        func stop() {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            AudioHardwareDestroyAggregateDevice(aggregateID)
            AudioHardwareDestroyProcessTap(tapID)
        }
    }

    private var routes: [String: Route] = [:]

    deinit { stopAll() }

    func stopAll() {
        for route in routes.values { route.stop() }
        routes.removeAll()
    }

    func stop(appID: String) {
        routes.removeValue(forKey: appID)?.stop()
    }

    func setVolume(_ percent: Double, for app: AudioApplication, outputDeviceID: AudioObjectID) throws {
        let gain = Float(min(max(percent, 0), 100) / 100)
        if gain >= 1 {
            stop(appID: app.id)
            return
        }
        if let route = routes[app.id],
           route.outputDeviceID == outputDeviceID, route.processIDs == app.processIDs {
            SoundMixGainStore(route.gainBox.storage, gain)
            return
        }

        routes.removeValue(forKey: app.id)?.stop()
        routes[app.id] = try makeRoute(for: app, outputDeviceID: outputDeviceID, gain: gain)
    }

    private func makeRoute(for app: AudioApplication, outputDeviceID: AudioObjectID, gain: Float) throws -> Route {
        guard outputDeviceID != kAudioObjectUnknown,
              let deviceUID = readString(outputDeviceID, kAudioDevicePropertyDeviceUID),
              !app.processIDs.isEmpty else { throw PerAppAudioError.noOutput }

        // A device-specific tap inherits the hardware stream's sample rate.
        let description = CATapDescription(processes: app.processIDs, deviceUID: deviceUID, stream: 0)
        description.name = "SoundMix · \(app.name)"
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped

        var tapID = AudioObjectID(kAudioObjectUnknown)
        let tapStatus = AudioHardwareCreateProcessTap(description, &tapID)
        guard tapStatus == noErr else { throw PerAppAudioError.coreAudio(tapStatus) }
        var aggregateID = AudioObjectID(kAudioObjectUnknown)
        var ioProcID: AudioDeviceIOProcID?
        var started = false
        defer {
            if !started {
                if let ioProcID { AudioDeviceDestroyIOProcID(aggregateID, ioProcID) }
                if aggregateID != kAudioObjectUnknown { AudioHardwareDestroyAggregateDevice(aggregateID) }
                AudioHardwareDestroyProcessTap(tapID)
            }
        }

        guard let tapUID = readString(tapID, kAudioTapPropertyUID) else {
            throw PerAppAudioError.unsupportedFormat
        }
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceUIDKey: "com.soundmix.route.\(UUID().uuidString)",
            kAudioAggregateDeviceNameKey: "SoundMix · \(app.name)",
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: deviceUID]],
            kAudioAggregateDeviceMainSubDeviceKey: deviceUID,
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: tapUID]],
            kAudioAggregateDeviceIsPrivateKey: true
        ]
        let aggregateStatus = AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregateID)
        guard aggregateStatus == noErr else { throw PerAppAudioError.coreAudio(aggregateStatus) }

        guard let tapFormat = readFormat(tapID, kAudioTapPropertyFormat),
              let outputFormat = readFormat(aggregateID, kAudioDevicePropertyStreamFormat, scope: kAudioDevicePropertyScopeOutput),
              isFloatStereo(tapFormat), isFloatStereo(outputFormat),
              tapFormat.mSampleRate == outputFormat.mSampleRate else {
            throw PerAppAudioError.unsupportedFormat
        }

        guard let gainBox = GainBox(gain) else { throw PerAppAudioError.noOutput }
        let inputIsPlanar = tapFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        let outputIsPlanar = outputFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        let createStatus = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil) {
            _, input, _, output, _ in
            let currentGain = SoundMixGainLoad(gainBox.storage)
            Self.render(input: input, output: output, gain: currentGain,
                        inputIsPlanar: inputIsPlanar, outputIsPlanar: outputIsPlanar)
        }
        guard createStatus == noErr, let ioProcID else { throw PerAppAudioError.coreAudio(createStatus) }

        let startStatus = AudioDeviceStart(aggregateID, ioProcID)
        guard startStatus == noErr else { throw PerAppAudioError.coreAudio(startStatus) }
        started = true
        return Route(tapID: tapID, aggregateID: aggregateID, ioProcID: ioProcID,
                     outputDeviceID: outputDeviceID, processIDs: app.processIDs, gainBox: gainBox)
    }

    nonisolated private static func render(input: UnsafePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>,
                                          gain: Float, inputIsPlanar: Bool, outputIsPlanar: Bool) {
        let inputs = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outputs = UnsafeMutableAudioBufferListPointer(output)
        let requiredInputBuffers = inputIsPlanar ? 2 : 1
        guard inputs.count >= requiredInputBuffers, outputs.count >= (outputIsPlanar ? 2 : 1) else { return }
        let inputStart = inputs.count - requiredInputBuffers

        for outputIndex in outputs.indices {
            let outputBuffer = outputs[outputIndex]
            guard let outputData = outputBuffer.mData else { continue }
            let outputChannels = max(Int(outputBuffer.mNumberChannels), 1)
            let outputSamples = Int(outputBuffer.mDataByteSize) / MemoryLayout<Float>.size
            let outputFrames = outputSamples / outputChannels
            let outputPointer = outputData.assumingMemoryBound(to: Float.self)

            for frame in 0..<outputFrames {
                for channel in 0..<outputChannels {
                    let stereoChannel = outputIsPlanar ? outputIndex : channel
                    guard stereoChannel < 2 else { continue }
                    let inputBuffer = inputs[inputStart + (inputIsPlanar ? stereoChannel : 0)]
                    guard let inputData = inputBuffer.mData else { continue }
                    let inputChannels = inputIsPlanar ? 1 : 2
                    let inputIndex = frame * inputChannels + (inputIsPlanar ? 0 : stereoChannel)
                    guard inputIndex < Int(inputBuffer.mDataByteSize) / MemoryLayout<Float>.size else { continue }
                    let inputPointer = inputData.assumingMemoryBound(to: Float.self)
                    outputPointer[frame * outputChannels + channel] = inputPointer[inputIndex] * gain
                }
            }
        }
    }

    private func isFloatStereo(_ format: AudioStreamBasicDescription) -> Bool {
        format.mFormatID == kAudioFormatLinearPCM &&
        format.mFormatFlags & kAudioFormatFlagIsFloat != 0 &&
        format.mBitsPerChannel == 32 && format.mChannelsPerFrame == 2
    }

    private func readFormat(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                            scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioStreamBasicDescription? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &format) == noErr else { return nil }
        return format
    }

    private func readString(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}
