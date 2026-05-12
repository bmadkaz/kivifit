import SwiftUI
import AVFoundation
import Combine

@MainActor
final class WorkoutViewModel: NSObject, ObservableObject {
    // MARK: - Published State
    @Published var landmarks: [PoseLandmark] = []
    @Published var currentError: String = ""
    @Published var fps: Int = 0
    @Published var processingStatus: String = "Инициализация..."
    @Published var selectedExercise: Exercise = .squat
    @Published var imageSize: CGSize = CGSize(width: 1280, height: 720)

    // MARK: - Services
    let captureSession: AVCaptureSession
    private let cameraManager = CameraManager()
    private let poseDetector = PoseDetectorManager(config: .init(frameSkip: 2, smoothingWindowSize: 4))
    private let analyzer = ExerciseAnalyzer()
    private let voiceCoach = VoiceCoach()

    // FPS tracking
    private var frameTimestamps: [Date] = []
    private var errorClearTask: Task<Void, Never>?

    override init() {
        captureSession = cameraManager.captureSession
        super.init()
        cameraManager.delegate = self
        poseDetector.delegate = self
    }

    // MARK: - Lifecycle
    func start() {
        processingStatus = "Запуск камеры..."
        cameraManager.startSession()
        voiceCoach.speak("KiviFit готов. Встаньте перед камерой и начните упражнение.")
    }

    func stop() {
        cameraManager.stopSession()
    }

    func selectExercise(_ exercise: Exercise) {
        selectedExercise = exercise
        currentError = ""
        voiceCoach.speak("Выбрано: \(exercise.rawValue)")
    }

    // MARK: - FPS Calculation
    private func updateFPS() {
        let now = Date()
        frameTimestamps.append(now)
        frameTimestamps = frameTimestamps.filter { now.timeIntervalSince($0) < 1.0 }
        fps = frameTimestamps.count
    }
}

// MARK: - CameraManagerDelegate
extension WorkoutViewModel: CameraManagerDelegate {
    nonisolated func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer) {
        poseDetector.process(sampleBuffer: sampleBuffer)
    }
}

// MARK: - PoseDetectorDelegate
extension WorkoutViewModel: PoseDetectorDelegate {
    nonisolated func poseDetector(_ detector: PoseDetectorManager,
                                   didDetect landmarks: [PoseLandmark],
                                   worldLandmarks: [PoseLandmark]) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.landmarks = landmarks
            self.updateFPS()
            self.processingStatus = landmarks.isEmpty ? "Поза не обнаружена" : "Анализ активен"

            guard !worldLandmarks.isEmpty else {
                self.currentError = ""
                return
            }

            // Analyze form errors
            let errors = self.analyzer.analyze(exercise: self.selectedExercise,
                                               landmarks: worldLandmarks)
            if let topError = errors.first(where: { $0.severity == .critical }) ?? errors.first {
                self.currentError = topError.message
                self.voiceCoach.announce(errors: errors)
            } else {
                self.scheduleErrorClear()
            }
        }
    }

    nonisolated func poseDetector(_ detector: PoseDetectorManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.processingStatus = "Ошибка: \(error.localizedDescription)"
        }
    }

    private func scheduleErrorClear() {
        errorClearTask?.cancel()
        errorClearTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled {
                currentError = ""
            }
        }
    }
}
