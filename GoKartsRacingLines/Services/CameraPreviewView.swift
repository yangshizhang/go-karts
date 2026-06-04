import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

final class CameraService: ObservableObject {
    let session = AVCaptureSession()
    @Published var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published var isRunning = false

    private var isConfigured = false
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    func requestAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            start()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { [weak self] in
                    self?.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    if granted { self?.start() }
                }
            }
        default:
            authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            self?.configureIfNeeded()
            guard let session = self?.session, !session.isRunning else { return }
            session.startRunning()
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = true
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let session = self?.session, session.isRunning else { return }
            session.stopRunning()
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        session.sessionPreset = .high
        defer {
            session.commitConfiguration()
            isConfigured = true
        }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }
        session.addInput(input)
    }
}
