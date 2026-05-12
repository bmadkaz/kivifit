import Foundation
import CoreMedia
import MediaPipeTasksVision

protocol PoseDetectorDelegate: AnyObject {
    func poseDetector(_ detector: PoseDetectorManager,
                      didDetect landmarks: [PoseLandmark],
                      worldLandmarks: [PoseLandmark])
    func poseDetector(_ detector: PoseDetectorManager, didFailWithError error: Error)
}

final class PoseDetectorManager: NSObject {

    // MARK: - Configuration
    struct Config {
        /// EMA smoothing factor: 0 = max smooth (laggy), 1 = no smooth (raw)
        /// 0.5 gives good balance for exercise tracking
        var emaAlpha: Float = 0.5
        var minPoseDetectionConfidence: Float = 0.5
        var minPosePresenceConfidence: Float = 0.5
        var minTrackingConfidence: Float = 0.5
    }

    // MARK: - Properties
    weak var delegate: PoseDetectorDelegate?
    private let config: Config
    private var poseLandmarker: PoseLandmarker?
    private let processingQueue = DispatchQueue(label: "com.kivifit.pose", qos: .userInteractive)
    /// Semaphore(1): tryWait drops new frame if detector is still busy
    private let frameGate = DispatchSemaphore(value: 1)
    /// EMA state — smooths without adding lag
    private var emaLandmarks: [PoseLandmark] = []

    // MARK: - Init
    init(config: Config = Config()) {
        self.config = config
        super.init()
        setupDetector()
    }

    // MARK: - Setup
    private func setupDetector() {
        let modelName = Bundle.main.path(forResource: "pose_landmarker_full", ofType: "task") != nil
            ? "pose_landmarker_full"
            : "pose_landmarker_heavy"

        guard let modelPath = Bundle.main.path(forResource: modelName, ofType: "task")
                           ?? Bundle.main.path(forResource: "pose_landmarker_lite", ofType: "task") else {
            print("[KiviFit] ❌ No model files found in bundle")
            return
        }

        do {
            let baseOptions = BaseOptions()
            baseOptions.modelAssetPath = modelPath

            let options = PoseLandmarkerOptions()
            options.baseOptions = baseOptions
            options.runningMode = .video
            options.numPoses = 1
            options.minPoseDetectionConfidence = config.minPoseDetectionConfidence
            options.minPosePresenceConfidence  = config.minPosePresenceConfidence
            options.minTrackingConfidence      = config.minTrackingConfidence

            poseLandmarker = try PoseLandmarker(options: options)
            print("[KiviFit] ✅ PoseLandmarker (\(modelName)) ready")
        } catch {
            print("[KiviFit] ❌ PoseLandmarker init failed: \(error)")
        }
    }

    // MARK: - Public API
    func process(sampleBuffer: CMSampleBuffer) {
        // Drop frame immediately if previous detection is still running
        guard frameGate.wait(timeout: .now()) == .success else { return }

        processingQueue.async { [weak self] in
            self?.detect(sampleBuffer: sampleBuffer)
            self?.frameGate.signal()
        }
    }

    // MARK: - Detection
    private func detect(sampleBuffer: CMSampleBuffer) {
        guard let landmarker = poseLandmarker else { return }

        // Use real presentation timestamp — critical for MediaPipe Kalman filter
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampMs = Int(CMTimeGetSeconds(pts) * 1000)
        guard timestampMs > 0 else { return }

        do {
            let mpImage = try MPImage(sampleBuffer: sampleBuffer)
            let result = try landmarker.detect(videoFrame: mpImage,
                                               timestampInMilliseconds: timestampMs)

            guard let poseLandmarks  = result.landmarks.first,
                  let worldLandmarks = result.worldLandmarks.first else {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.emaLandmarks = []
                    self.delegate?.poseDetector(self, didDetect: [], worldLandmarks: [])
                }
                return
            }

            let normalized = poseLandmarks.map {
                PoseLandmark(x: $0.x, y: $0.y, z: $0.z,
                             visibility: $0.visibility?.floatValue ?? 0,
                             presence:   $0.presence?.floatValue   ?? 0)
            }
            let world = worldLandmarks.map {
                PoseLandmark(x: $0.x, y: $0.y, z: $0.z,
                             visibility: $0.visibility?.floatValue ?? 0,
                             presence:   $0.presence?.floatValue   ?? 0)
            }

            let smoothed = applyEMA(to: normalized)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.poseDetector(self, didDetect: smoothed, worldLandmarks: world)
            }

        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.poseDetector(self, didFailWithError: error)
            }
        }
    }

    // MARK: - EMA Smoothing
    // Exponential moving average: zero added latency, removes jitter.
    // alpha=0.5: equal weight to new and history → smooth but responsive.
    private func applyEMA(to landmarks: [PoseLandmark]) -> [PoseLandmark] {
        guard !emaLandmarks.isEmpty, emaLandmarks.count == landmarks.count else {
            emaLandmarks = landmarks
            return landmarks
        }
        let a = config.emaAlpha
        let b = 1 - a
        emaLandmarks = zip(emaLandmarks, landmarks).map { prev, curr in
            PoseLandmark(
                x:          a * curr.x          + b * prev.x,
                y:          a * curr.y          + b * prev.y,
                z:          a * curr.z          + b * prev.z,
                visibility: a * curr.visibility + b * prev.visibility,
                presence:   curr.presence
            )
        }
        return emaLandmarks
    }
}
