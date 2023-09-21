//
//  CaptureViewModel.swift
//  ExternalCapture
//
//  Created by Khaos Tian on 6/7/23.
//

import AVFoundation
import Foundation
import UIKit
import Observation

@Observable
class CaptureViewModel {

    var hasVideoAccess: Bool = false

    var availableVideoInputs: [AVCaptureDevice] = []
    var availableAudioInputs: [AVCaptureDevice] = []

    var isCapturing = false
    var captureSession: AVCaptureSession?

    var activeVideoDevice: AVCaptureDevice?
    var activeAudioDevice: AVCaptureDevice?

    private var lastConnectedDeviceName: String?

    private var audioPreviewOutput: AudioPlaybackOutput?

    private var notificationObservations: [NSObjectProtocol] = []

    var availableVideoFormats: [AVCaptureDevice.Format]? {
        return activeVideoDevice?.formats.filter { $0.mediaType == .video }
    }
    var availablePresets: [AVCaptureSession.Preset] {
        return [
            .hd4K3840x2160,
            .hd1920x1080,
            .hd1280x720,
            .photo,
            .high,
            .medium,
            .low,
        ].filter { captureSession?.canSetSessionPreset($0) ?? false }
    }

    init() {
        hasVideoAccess = AVCaptureDevice.authorizationStatus(for: .video) == .authorized

        updateInputDevices()

        notificationObservations.append(
            NotificationCenter.default.addObserver(
                forName: .AVCaptureDeviceWasConnected,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    self?.handleDeviceConnected()
                }
            )
        )

        notificationObservations.append(
            NotificationCenter.default.addObserver(
                forName: .AVCaptureDeviceWasDisconnected,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    self?.handleDeviceDisconnected(notification)
                }
            )
        )
    }

    deinit {
        for observation in notificationObservations {
            NotificationCenter.default.removeObserver(observation)
        }

        notificationObservations.removeAll()
    }

    func requestVideoAccessPermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        hasVideoAccess = granted

        updateInputDevices()
    }

    private func handleDeviceConnected() {
        updateInputDevices()
        autoReconnectIfPossible()
    }

    private func handleDeviceDisconnected(_ notification: Notification) {
        updateInputDevices()

        guard let device = notification.object as? AVCaptureDevice else {
            return
        }

        if activeVideoDevice == device {
            teardown()
        }
    }

    private func updateInputDevices() {
        guard hasVideoAccess else {
            return
        }

        let cameraSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .external,
            ],
            mediaType: .video,
            position: .unspecified
        )

        availableVideoInputs = cameraSession.devices.sorted(by: { $0.localizedName < $1.localizedName })

        let audioSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .external,
                .microphone,
            ],
            mediaType: .audio,
            position: .unspecified
        )

        availableAudioInputs = audioSession.devices.sorted(by: { $0.localizedName < $1.localizedName })
    }

    private func autoReconnectIfPossible() {
        /// Auto reconnect if we have connected it in the past.
        if let lastConnectedDeviceName,
           let videoDevice = availableVideoInputs.first(where: { $0.localizedName == lastConnectedDeviceName}) {
            startCapture(videoDevice: videoDevice)
        }
    }

    func startCapture(videoDevice: AVCaptureDevice) {
        guard hasVideoAccess, !isCapturing, captureSession == nil else {
            return
        }

        isCapturing = true
        configureInput(videoDevice: videoDevice)

        lastConnectedDeviceName = videoDevice.localizedName
    }

    func updateAudioDeviceSelection(audioDevice: AVCaptureDevice) {
        guard let activeVideoDevice, activeAudioDevice != audioDevice else {
            return
        }

        configureInput(videoDevice: activeVideoDevice, audioDevice: audioDevice)
    }

    func updateVideoFormatSelection(videoFormat: AVCaptureDevice.Format) {
        guard let activeVideoDevice,
              videoFormat != activeVideoDevice.activeFormat else {
            return
        }

        do {
            try activeVideoDevice.lockForConfiguration()
            activeVideoDevice.activeFormat = videoFormat
            activeVideoDevice.unlockForConfiguration()
            _$observationRegistrar.willSet(self, keyPath: \.activeVideoDevice)
            _$observationRegistrar.didSet(self, keyPath: \.activeVideoDevice)
        } catch {
            NSLog("Failed to update device, error: \(error)")
        }
    }

    func updateSessionPresetSelection(preset: AVCaptureSession.Preset) {
        guard preset != captureSession?.sessionPreset else {
            return
        }

        captureSession?.sessionPreset = preset
        _$observationRegistrar.willSet(self, keyPath: \.captureSession)
        _$observationRegistrar.didSet(self, keyPath: \.captureSession)
    }

    private func configureInput(videoDevice: AVCaptureDevice, audioDevice: AVCaptureDevice? = nil) {
        if activeVideoDevice != nil {
            captureSession?.stopRunning()
        }

        activeAudioDevice = nil

        let captureSession = AVCaptureSession()
        activeVideoDevice = videoDevice

        if captureSession.isMultitaskingCameraAccessSupported {
            captureSession.isMultitaskingCameraAccessEnabled = true
        }

        do {
            try videoDevice.lockForConfiguration()
        } catch {
            NSLog("Unable to lock device")
        }

        captureSession.beginConfiguration()
        guard let videoInputDevice = try? AVCaptureDeviceInput(device: videoDevice),
            captureSession.canAddInput(videoInputDevice) else {
                NSLog("Can't add it.")
                captureSession.commitConfiguration()
                return
        }

        captureSession.addInput(videoInputDevice)

        let recommendedAudioDevice: AVCaptureDevice? = {
            if let audioDevice = audioDevice {
                return audioDevice
            }

            let audioDiscoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .external,
                    .microphone,
                ],
                mediaType: .audio,
                position: .unspecified
            )

            let possibleAudioDevices = audioDiscoverySession.devices.filter { $0.localizedName == videoDevice.localizedName }

            if possibleAudioDevices.count == 1 {
                return possibleAudioDevices.first
            } else {
                return nil
            }
        }()

        if let recommendedAudioDevice = recommendedAudioDevice,
           let audioInputDevice = try? AVCaptureDeviceInput(device: recommendedAudioDevice),
           captureSession.canAddInput(audioInputDevice) {
            activeAudioDevice = recommendedAudioDevice

            self.audioPreviewOutput = AudioPlaybackOutput(captureSession: captureSession, input: audioInputDevice)
        } else {
            self.audioPreviewOutput = nil
        }

        captureSession.commitConfiguration()
        videoDevice.unlockForConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()

            DispatchQueue.main.async {
                self.captureSession = captureSession
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }

    private func teardown() {
        self.activeVideoDevice = nil
        self.activeAudioDevice = nil
        self.audioPreviewOutput = nil
        self.captureSession?.stopRunning()
        self.captureSession = nil
        self.isCapturing = false

        UIApplication.shared.isIdleTimerDisabled = true
    }
}

class AudioPlaybackOutput: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {

    let output = AVCaptureAudioDataOutput()
    let queue = DispatchQueue(label: "audio")

    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioConverter: AVAudioConverter?
    private let outputFormat: AVAudioFormat = {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100.0, channels: 2, interleaved: false)
        return format!
    }()

    init(captureSession: AVCaptureSession, input: AVCaptureDeviceInput) {
        super.init()
        output.setSampleBufferDelegate(self, queue: queue)

        captureSession.addInput(input)
        captureSession.addOutput(output)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NSLog("Error: \(error)")
        }
    }

    deinit {
        audioPlayerNode?.stop()
        audioEngine?.stop()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = scheduleBuffer(sampleBuffer) else { return }
        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: buffer.frameCapacity)

        do {
            try audioConverter?.convert(to: pcmBuffer!, from: buffer)
        } catch {
            NSLog("Error: \(error)")
        }

        audioPlayerNode?.scheduleBuffer(pcmBuffer!, completionHandler: nil)
    }

    func initAudioEngine(_ audioFormat: AVAudioFormat?) {
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()
        audioConverter = AVAudioConverter(from: audioFormat!, to: outputFormat)

        audioEngine?.attach(audioPlayerNode!)
        audioEngine?.connect(audioPlayerNode!, to: audioEngine!.outputNode, format: outputFormat)
        audioEngine?.prepare()

        do {
            try audioEngine?.start()
            audioPlayerNode?.play()
        } catch {
            NSLog("Error: \(error)")
        }
    }

    func scheduleBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let sDescr = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil}
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        let avFmt = AVAudioFormat(cmAudioFormatDescription: sDescr)

        if audioEngine == nil {
            initAudioEngine(avFmt)
        }

        let pcmBuffer = AVAudioPCMBuffer(pcmFormat: avFmt, frameCapacity: AVAudioFrameCount(UInt(numSamples)))
        pcmBuffer?.frameLength = AVAudioFrameCount(numSamples)

        if let mutableAudioBufferList = pcmBuffer?.mutableAudioBufferList {
            CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, at: 0, frameCount: Int32(numSamples), into: mutableAudioBufferList)
        }

        return pcmBuffer
    }
}
