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

    var previewLayer: AVCaptureVideoPreviewLayer?
    var session: AVCaptureSession? {
        get { previewLayer?.session }
        set {
            guard previewLayer?.session !== newValue else {
                return
            }

            setupLayer()
            previewLayer?.session = newValue
            previewLayer?.connection?.automaticallyAdjustsVideoMirroring = false
            previewLayer?.connection?.isVideoMirrored = false
            previewLayer?.connection?.videoRotationAngle = 0
        }
    }

    init() {
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayer() {
        if previewLayer != nil {
            previewLayer?.removeFromSuperlayer()
        }

        let previewLayer = AVCaptureVideoPreviewLayer()
        self.previewLayer = previewLayer
        
        self.layer.addSublayer(previewLayer)
        previewLayer.frame = self.bounds
    }

    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        previewLayer?.frame = self.bounds
    }
}
