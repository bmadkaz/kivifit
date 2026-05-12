import Foundation
import CoreMedia
import MediaPipeTasksVision

/// Delegate protocol for receiving pose detection results
protocol PoseDetectorDelegate: AnyObject {
    func poseDetector(_ detector: PoseDetectorManager,
                      didDetect landmarks: [NormalizedLandmark],
                      worldLandmarks: [NormalizedLandmark])
    func poseDetector(_ detector: PoseDetectorManager, didFailWithError error: Error)
}

/// Manages MediaPipe pose landmark detection with GPU acceleration, frame skipping,
/// and smoothing. Uses PoseLandmarker Heavy model for maximum accuracy.
final class PoseDetectorManager: NSObject {

    // MARK: - Configuration
    struct Config {
        /// Process every N-th frame to prevent overheating
        var frameSkip: Int = 2
        /// Minimum landmark detection confidence
        var minPoseDetectionConfidence: Float = 0.5
        var minPosePresenceConfidence: Float = 0.5
        var minTrackingConfidence: Float = 0.5
        /// Smoothing window size
        var smoothingWindowSize: Int = 5
    }

    // MARK: - Properties
    weak var delegate: PoseDetectorDelegate?
    private let config: Config
    private var poseLandmarker: PoseLandmarker?
    private var frameCounter: Int = 0
    private let processingQueue = DispatchQueue(label: "com.kivifit.pose", qos: .userInteractive)
    private var smoothingBuffers: [[NormalizedLandmark]] = []
    private var timestampMs: Int = 0

    // MARK: - Init
    init(config: Config = Config()) {
        self.config = config
        super.init()
        setupDetector()
    }

    // MARK: - Setup
    private func setupDetector() {
        guard let modelPath = Bundle.main.path(
            forResource: "pose_landmarker_heavy",
            ofType: "task"
        ) else {
            print("[KiviFit] ⚠️ Model file not found. Using lite model as fallback.")
            setupFallbackDetector()
            return
        }

        do {
            let baseOptions = BaseOptions(modelAssetPath: modelPath)
            // Force GPU (Metal) delegate for iOS
            baseOptions.delegate = .GPU

            let options = PoseLandmarkerOptions()
            options.baseOptions = baseOptions
            options.runningMode = .video
            options.numPoses = 1
            options.minPoseDetectionConfidence = config.minPoseDetectionConfidence
            options.minPosePresenceConfidence = config.minPosePresenceConfidence
            options.minTrackingConfidence = config.minTrackingConfidence

            poseLandmarker = try PoseLandmarker(options: options)
            print("[KiviFit] ✅ PoseLandmarker (heavy) initialized on GPU")
        } catch {
            print("[KiviFit] ❌ Failed to init PoseLandmarker: \(error)")
            setupFallbackDetector()
        }
    }

    private func setupFallbackDetector() {
        // Fallback to lite model if heavy not available
        guard let modelPath = Bundle.main.path(
            forResource: "pose_landmarker_lite",
            ofType: "task"
        ) else {
            print("[KiviFit] ❌ No model files found in bundle")
            return
        }
        do {
            let baseOptions = BaseOptions(modelAssetPath: modelPath)
            baseOptions.delegate = .GPU
            let options = PoseLandmarkerOptions()
            options.baseOptions = baseOptions
            options.runningMode = .video
            options.numPoses = 1
            poseLandmarker = try PoseLandmarker(options: options)
            print("[KiviFit] ⚠️ Using lite fallback model")
        } catch {
            print("[KiviFit] ❌ Fallback also failed: \(error)")
        }
    }

    // MARK: - Public API
    /// Call this for each CMSampleBuffer from AVCaptureOutput
    func process(sampleBuffer: CMSampleBuffer) {
        frameCounter += 1
        guard frameCounter % config.frameSkip == 0 else { return }

        processingQueue.async { [weak self] in
            self?.detect(sampleBuffer: sampleBuffer)
        }
    }

    // MARK: - Detection
    private func detect(sampleBuffer: CMSampleBuffer) {
        guard let landmarker = poseLandmarker else { return }

        timestampMs += 33 // approximate 30fps timestamp increment

        do {
            let mpImage = try MPImage(sampleBuffer: sampleBuffer)
            let result = try landmarker.detect(videoFrame: mpImage,
                                               timestampInMilliseconds: timestampMs)

            guard let poseLandmarks = result.landmarks.first,
                  let worldLandmarks = result.worldLandmarks.first else {
                // No pose detected
                DispatchQueue.main.async {
                    self.delegate?.poseDetector(self, didDetect: [], worldLandmarks: [])
                }
                return
            }

            // Convert MediaPipe landmarks to our model
            let normalized = poseLandmarks.map { lm in
                NormalizedLandmark(
                    x: lm.x, y: lm.y, z: lm.z,
                    visibility: lm.visibility ?? 0,
                    presence: lm.presence ?? 0
                )
            }
            let world = worldLandmarks.map { lm in
                NormalizedLandmark(
                    x: lm.x, y: lm.y, z: lm.z,
                    visibility: lm.visibility ?? 0,
                    presence: lm.presence ?? 0
                )
            }

            // Apply smoothing
            let smoothed = applySmoothingFilter(to: normalized)

            DispatchQueue.main.async {
                self.delegate?.poseDetector(self, didDetect: smoothed, worldLandmarks: world)
            }

        } catch {
            DispatchQueue.main.async {
                self.delegate?.poseDetector(self, didFailWithError: error)
            }
        }
    }

    // MARK: - Smoothing (sliding window average)
    private func applySmoothingFilter(to landmarks: [NormalizedLandmark]) -> [NormalizedLandmark] {
        smoothingBuffers.append(landmarks)
        if smoothingBuffers.count > config.smoothingWindowSize {
            smoothingBuffers.removeFirst()
        }
        guard smoothingBuffers.count > 1 else { return landmarks }

        let count = landmarks.count
        var result = landmarks
        for i in 0..<count {
            var sumX: Float = 0, sumY: Float = 0, sumZ: Float = 0
            var sumVis: Float = 0
            for frame in smoothingBuffers {
                guard i < frame.count else { continue }
                sumX += frame[i].x
                sumY += frame[i].y
                sumZ += frame[i].z
                sumVis += frame[i].visibility
            }
            let n = Float(smoothingBuffers.count)
            result[i] = NormalizedLandmark(
                x: sumX / n, y: sumY / n, z: sumZ / n,
                visibility: sumVis / n,
                presence: landmarks[i].presence
            )
        }
        return result
    }
}
