//
//  ContentView.swift
//  ExternalCapture
//
//  Created by Khaos Tian on 6/7/23.
//

import SwiftUI

struct CaptureSessionView: View {

    @State var viewModel = CaptureViewModel()

    @State var isShowingDeviceSelector = false
    @State var shouldHideOverlay = false

    var body: some View {
        ZStack {
            CameraPreviewView(captureSession: viewModel.captureSession)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            VStack {
                HStack(spacing: 16) {
                    if let videoDevice = viewModel.activeVideoDevice {
                        Text(videoDevice.localizedName)
                            .imageScale(.large)
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8.0))
                            .foregroundStyle(.foreground)
                    }
                    Spacer()
                    Button(action: showDeviceList) {
                        Image(systemName: "tv")
                            .imageScale(.large)
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(Circle())
                            .foregroundStyle(.foreground)
                    }
                    .popover(isPresented: $isShowingDeviceSelector) {
                        List {
                            Section("Video Input") {
                                if !viewModel.availableVideoInputs.isEmpty {
                                    ForEach(viewModel.availableVideoInputs, id: \.uniqueID) { device in
                                        Button(
                                            action: {
                                                viewModel.startCapture(videoDevice: device)
                                                isShowingDeviceSelector = false
                                            },
                                            label: {
                                                HStack {
                                                    Text(device.localizedName)
                                                    Spacer()
                                                    if device == viewModel.activeVideoDevice {
                                                        Circle()
                                                            .frame(width: 16, height: 16, alignment: .center)
                                                            .foregroundStyle(.green)
                                                    }
                                                }
                                                .foregroundStyle(.foreground)
                                            }
                                        )
                                    }
                                } else {
                                    Text("No Device")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Section("Audio Input") {
                                if !viewModel.availableAudioInputs.isEmpty {
                                    ForEach(viewModel.availableAudioInputs, id: \.uniqueID) { device in
                                        Button(
                                            action: {
                                                viewModel.updateAudioDeviceSelection(audioDevice: device)
                                                isShowingDeviceSelector = false
                                            },
                                            label: {
                                                HStack {
                                                    Text(device.localizedName)
                                                    Spacer()
                                                    if device == viewModel.activeAudioDevice {
                                                        Circle()
                                                            .frame(width: 16, height: 16, alignment: .center)
                                                            .foregroundStyle(.orange)
                                                    }
                                                }
                                                .foregroundStyle(.foreground)
                                            }
                                        )
                                    }
                                } else {
                                    Text("No Device")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let videoFormats = viewModel.availableVideoFormats {
                                Section("Video Format") {
                                    ForEach(videoFormats, id: \.formatDescription) { format in
                                        Button(
                                            action: {
                                                viewModel.updateVideoFormatSelection(videoFormat: format)
                                            },
                                            label: {
                                                HStack {
                                                    VStack(alignment: .leading) {
                                                        let frameRates = format.videoSupportedFrameRateRanges
                                                            .map { String(format: "%.2f fps", $0.maxFrameRate) }
                                                            .joined(separator: ",")

                                                        let dimensions = format.formatDescription.dimensions

                                                        Text("\(dimensions.width) × \(dimensions.height)")
                                                        Text("\(frameRates) - \(format.formatDescription.mediaSubType.description)")
                                                            .font(.callout)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    Spacer()
                                                    if viewModel.activeVideoDevice?.activeFormat == format {
                                                        Circle()
                                                            .frame(width: 16, height: 16, alignment: .center)
                                                            .foregroundStyle(.green)
                                                    }
                                                }
                                                .foregroundStyle(.foreground)
                                            }
                                        )
                                    }
                                }
                            }

                            if viewModel.activeVideoDevice != nil {
                                Section("Preset") {
                                    ForEach(viewModel.availablePresets, id: \.self) { preset in
                                        Button(
                                            action: {
                                                viewModel.updateSessionPresetSelection(preset: preset)
                                            },
                                            label: {
                                                HStack {
                                                    VStack(alignment: .leading) {
                                                        Text("\(preset.rawValue)")
                                                    }
                                                    Spacer()
                                                    if viewModel.captureSession?.sessionPreset == preset {
                                                        Circle()
                                                            .frame(width: 16, height: 16, alignment: .center)
                                                            .foregroundStyle(.green)
                                                    }
                                                }
                                                .foregroundStyle(.foreground)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .frame(minWidth: 300, minHeight: 300)
                        .listStyle(.insetGrouped)
                        .preferredColorScheme(.dark)
                    }
                }

                Spacer()
            }
            .padding()
            .opacity(shouldHideOverlay ? 0.0 : 1.0)

            if !viewModel.hasVideoAccess {
                VStack {
                    Text("Permission needed to access external input devices.")

                    Button("Grant Access") {
                        Task {
                            await viewModel.requestVideoAccessPermission()
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .foregroundStyle(.foreground)
                }
                .padding()
            } else if viewModel.activeVideoDevice == nil {
                VStack {
                    Text("Select input device to start")

                    Button("Select Device") {
                        isShowingDeviceSelector = true
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .foregroundStyle(.foreground)
                }
                .padding()
            }
        }
        .onTapGesture {
            shouldHideOverlay.toggle()
        }
        .preferredColorScheme(.dark)
    }

    private func showDeviceList() {
        isShowingDeviceSelector = true
    }
}
