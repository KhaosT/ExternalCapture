//
//  CameraView.swift
//  ExternalCapture
//
//  Created by Khaos Tian on 6/7/23.
//

import AVFoundation
import SwiftUI

struct CameraPreviewView: UIViewRepresentable {

    typealias UIViewType = CameraPreviewInternalView

    var captureSession: AVCaptureSession?

    init(captureSession: AVCaptureSession?) {
        self.captureSession = captureSession
    }

    func makeUIView(context: Context) -> CameraPreviewInternalView {
        let view = CameraPreviewInternalView()
        view.backgroundColor = .black
        view.session = captureSession
        return view
    }

    func updateUIView(_ view: CameraPreviewInternalView, context: Context) {
        view.session = captureSession
    }
}

class CameraPreviewInternalView: UIView {

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession? {
        get { previewLayer.session }
        set {
            guard previewLayer.session !== newValue else {
                return
            }

            previewLayer.session = newValue
            previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
            previewLayer.connection?.isVideoMirrored = false
            previewLayer.connection?.videoRotationAngle = 0
        }
    }
}
