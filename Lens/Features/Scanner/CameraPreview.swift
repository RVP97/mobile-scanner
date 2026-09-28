@preconcurrency import AVFoundation
import SwiftUI
import UIKit

/// A view whose backing layer is the capture preview. Keeps the preview upright in every interface
/// orientation with `AVCaptureDevice.RotationCoordinator`.
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    // `layerClass` guarantees the type.
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func attach(session: AVCaptureSession, device: AVCaptureDevice) {
        if previewLayer.session !== session { previewLayer.session = session }
        guard rotationCoordinator?.device !== device else { return }

        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        rotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.initial, .new]
        ) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            Task { @MainActor in self?.applyRotation(angle) }
        }
    }

    private func applyRotation(_ angle: CGFloat) {
        guard let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }
}

/// SwiftUI host for the camera preview. Gestures live on this view: tap to focus, pinch to zoom.
struct CameraPreview: UIViewRepresentable {
    let camera: ScannerCamera

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        camera.connect(view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
