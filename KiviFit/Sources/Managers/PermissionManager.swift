import AVFoundation

final class PermissionManager {
    static let shared = PermissionManager()

    func requestAll(completion: @escaping (Bool, String) -> Void) {
        requestCamera { [weak self] cameraGranted in
            guard cameraGranted else {
                completion(false, "Необходим доступ к камере для анализа позы. Пожалуйста, разрешите в Настройках.")
                return
            }
            self?.requestMicrophone { micGranted in
                // Mic optional (for audio output via TTS)
                completion(true, "")
            }
        }
    }

    private func requestCamera(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    private func requestMicrophone(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(true) // mic not critical
        }
    }
}
