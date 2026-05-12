import Foundation
import AVFoundation
import CoreMedia

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer)
}

final class CameraManager: NSObject {
    weak var delegate: CameraManagerDelegate?
    let captureSession = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.kivifit.camera.session")
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private(set) var imageSize: CGSize = .zero

    override init() {
        super.init()
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720

        // Front camera
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ) else {
            print("[KiviFit] ❌ Front camera not available")
            captureSession.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print("[KiviFit] ❌ Camera input error: \(error)")
            captureSession.commitConfiguration()
            return
        }

        // Video output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.kivifit.camera.output"))

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }

        // Mirror for front camera
        if let connection = output.connection(with: .video) {
            connection.isVideoMirrored = true
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        self.videoDataOutput = output
        imageSize = CGSize(width: 1280, height: 720)

        captureSession.commitConfiguration()
        captureSession.startRunning()
        print("[KiviFit] ✅ Camera session started")
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        delegate?.cameraManager(self, didOutput: sampleBuffer)
    }
}
