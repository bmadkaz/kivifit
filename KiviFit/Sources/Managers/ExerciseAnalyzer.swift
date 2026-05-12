import Foundation
import simd

/// All supported exercises
enum Exercise: String, CaseIterable {
    case squat = "Приседание"
    case pushup = "Отжимание"
    case plank = "Планка"
    case lunge = "Выпад"
    case deadlift = "Становая тяга"
    case shoulderPress = "Жим плечами"
}

/// A single detected form error with severity
struct FormError {
    enum Severity { case warning, critical }
    let message: String
    let severity: Severity
}

/// Analyzes 3-D world landmarks for exercise-specific form errors.
/// All index constants follow MediaPipe Pose 33-landmark schema.
final class ExerciseAnalyzer {

    // MARK: - Landmark indices
    private enum LM: Int {
        case nose = 0
        case leftShoulder = 11, rightShoulder = 12
        case leftElbow = 13, rightElbow = 14
        case leftWrist = 15, rightWrist = 16
        case leftHip = 23, rightHip = 24
        case leftKnee = 25, rightKnee = 26
        case leftAnkle = 27, rightAnkle = 28
        case leftHeel = 29, rightHeel = 30
        case leftFootIndex = 31, rightFootIndex = 32
    }

    // MARK: - Public
    func analyze(exercise: Exercise,
                 landmarks: [NormalizedLandmark]) -> [FormError] {
        guard landmarks.count >= 33 else { return [] }
        switch exercise {
        case .squat:          return analyzeSquat(landmarks)
        case .pushup:         return analyzePushUp(landmarks)
        case .plank:          return analyzePlank(landmarks)
        case .lunge:          return analyzeLunge(landmarks)
        case .deadlift:       return analyzeDeadlift(landmarks)
        case .shoulderPress:  return analyzeShoulderPress(landmarks)
        }
    }

    // MARK: - Angle Helpers
    private func angle(a: NormalizedLandmark,
                       b: NormalizedLandmark,
                       c: NormalizedLandmark) -> Float {
        let ba = SIMD3<Float>(a.x - b.x, a.y - b.y, a.z - b.z)
        let bc = SIMD3<Float>(c.x - b.x, c.y - b.y, c.z - b.z)
        let cosA = dot(ba, bc) / (length(ba) * length(bc) + 1e-8)
        return acos(max(-1, min(1, cosA))) * (180 / .pi)
    }

    private func lm(_ landmarks: [NormalizedLandmark], _ index: LM) -> NormalizedLandmark {
        landmarks[index.rawValue]
    }

    private func midpoint(_ a: NormalizedLandmark, _ b: NormalizedLandmark) -> NormalizedLandmark {
        NormalizedLandmark(x: (a.x+b.x)/2, y: (a.y+b.y)/2, z: (a.z+b.z)/2,
                           visibility: min(a.visibility, b.visibility), presence: min(a.presence, b.presence))
    }

    // MARK: - Squat Analysis
    private func analyzeSquat(_ lms: [NormalizedLandmark]) -> [FormError] {
        var errors: [FormError] = []
        let leftKneeAngle  = angle(a: lm(lms, .leftHip),  b: lm(lms, .leftKnee),  c: lm(lms, .leftAnkle))
        let rightKneeAngle = angle(a: lm(lms, .rightHip), b: lm(lms, .rightKnee), c: lm(lms, .rightAnkle))
        let avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2

        // Knee cave (valgus): knees inside ankles
        let leftKneeInward  = lm(lms, .leftKnee).x > lm(lms, .leftAnkle).x + 0.04
        let rightKneeInward = lm(lms, .rightKnee).x < lm(lms, .rightAnkle).x - 0.04
        if leftKneeInward || rightKneeInward {
            errors.append(FormError(message: "Колени завалились внутрь", severity: .critical))
        }

        // Back rounding: hip-shoulder angle
        let hipCenter = midpoint(lm(lms, .leftHip), lm(lms, .rightHip))
        let shoulderCenter = midpoint(lm(lms, .leftShoulder), lm(lms, .rightShoulder))
        let backLean = abs(shoulderCenter.x - hipCenter.x)
        if backLean > 0.15 {
            errors.append(FormError(message: "Спина наклонена слишком вперёд", severity: .warning))
        }

        // Depth check
        if avgKneeAngle > 110 {
            errors.append(FormError(message: "Недостаточная глубина приседания", severity: .warning))
        }

        // Heels lifting
        let heelDiff = abs(lm(lms, .leftHeel).y - lm(lms, .leftAnkle).y)
        if heelDiff > 0.05 {
            errors.append(FormError(message: "Пятки отрываются от пола", severity: .critical))
        }

        return errors
    }

    // MARK: - Push-Up Analysis
    private func analyzePushUp(_ lms: [NormalizedLandmark]) -> [FormError] {
        var errors: [FormError] = []
        let leftElbowAngle  = angle(a: lm(lms, .leftShoulder),  b: lm(lms, .leftElbow),  c: lm(lms, .leftWrist))
        let rightElbowAngle = angle(a: lm(lms, .rightShoulder), b: lm(lms, .rightElbow), c: lm(lms, .rightWrist))

        // Elbows too wide (>75° from body)
        if leftElbowAngle < 60 || rightElbowAngle < 60 {
            errors.append(FormError(message: "Локти слишком развёрнуты наружу", severity: .warning))
        }

        // Hips sagging
        let hipCenter = midpoint(lm(lms, .leftHip), lm(lms, .rightHip))
        let shoulderCenter = midpoint(lm(lms, .leftShoulder), lm(lms, .rightShoulder))
        let kneeCenter = midpoint(lm(lms, .leftKnee), lm(lms, .rightKnee))
        let bodyLineDeviation = abs(hipCenter.y - (shoulderCenter.y + kneeCenter.y) / 2)
        if bodyLineDeviation > 0.06 {
            errors.append(FormError(message: "Таз провисает вниз", severity: .critical))
        }

        // Head drooping
        let nose = lm(lms, .nose)
        if nose.y > shoulderCenter.y + 0.08 {
            errors.append(FormError(message: "Голова опускается вниз", severity: .warning))
        }

        return errors
    }

    // MARK: - Plank Analysis
    private func analyzePlank(_ lms: [NormalizedLandmark]) -> [FormError] {
        var errors: [FormError] = []
        let hipCenter = midpoint(lm(lms, .leftHip), lm(lms, .rightHip))
        let shoulderCenter = midpoint(lm(lms, .leftShoulder), lm(lms, .rightShoulder))
        let ankleCenter = midpoint(lm(lms, .leftAnkle), lm(lms, .rightAnkle))

        // Hip too high or too low
        let expectedHipY = (shoulderCenter.y + ankleCenter.y) / 2
        let hipDeviation = hipCenter.y - expectedHipY
        if hipDeviation < -0.08 {
            errors.append(FormError(message: "Таз слишком высоко поднят", severity: .warning))
        } else if hipDeviation > 0.08 {
            errors.append(FormError(message: "Таз провисает вниз", severity: .critical))
        }

        return errors
    }

    // MARK: - Lunge Analysis
    private func analyzeLunge(_ lms: [NormalizedLandmark]) -> [FormError] {
        var errors: [FormError] = []
        let frontKneeAngle = angle(a: lm(lms, .leftHip), b: lm(lms, .leftKnee), c: lm(lms, .leftAnkle))

        // Knee over toes
        if lm(lms, .leftKnee).z < lm(lms, .leftFootIndex).z - 0.05 {
            errors.append(FormError(message: "Колено выходит за носок", severity: .critical))
        }
        // Torso upright
        let hipCenter = midpoint(lm(lms, .leftHip), lm(lms, .rightHip))
        let shoulderCenter = midpoint(lm(lms, .leftShoulder), lm(lms, .rightShoulder))
        if abs(shoulderCenter.x - hipCenter.x) > 0.12 {
            errors.append(FormError(message: "Корпус наклонён вперёд", severity: .warning))
        }
        if frontKneeAngle < 70 {
            errors.append(FormError(message: "Слишком глубокий выпад, уменьшите угол", severity: .warning))
        }
        return errors
    }

    // MARK: - Deadlift Analysis
    private func analyzeDeadlift(_ lms: [NormalizedLandmark]) -> [FormError] {
        var errors: [FormError] = []
        let hipCenter = midpoint(lm(lms, .leftHip), lm(lms, .rightHip))
        let shoulderCenter = midpoint(lm(lms, .leftShoulder), lm(lms, .rightShoulder))

        // Back rounding
        let spineAngle = angle(a: shoulderCenter, b: hipCenter,
                               c: midpoint(lm(lms, .leftKnee), lm(lms, .rightKnee)))
        if spineAngle < 150 {
            errors.append(FormError(message: "Спина округлена, держите её прямо", severity: .critical))
        }

        // Bar path (wrists should be close to body)
        let wristCenter = midpoint(lm(lms, .leftWrist), lm(lms, .rightWrist))
        if abs(wristCenter.z - hipCenter.z) > 0.15 {
            errors.append(FormError(message: "Штанга далеко от тела", severity: .warning))
        }

        return errors
    }

    // MARK: - Shoulder Press Analysis
    private func analyzeShoulderPress(_ lms: [NormalizedLandmark]) -> [FormError] {
        var errors: [FormError] = []
        let leftPressAngle  = angle(a: lm(lms, .leftElbow),  b: lm(lms, .leftShoulder),  c: lm(lms, .leftHip))
        let rightPressAngle = angle(a: lm(lms, .rightElbow), b: lm(lms, .rightShoulder), c: lm(lms, .rightHip))

        // Elbows behind ears at top
        if leftPressAngle < 160 || rightPressAngle < 160 {
            errors.append(FormError(message: "Вытяните руки полностью вверх", severity: .warning))
        }

        // Lower back arch
        let hipCenter = midpoint(lm(lms, .leftHip), lm(lms, .rightHip))
        let shoulderCenter = midpoint(lm(lms, .leftShoulder), lm(lms, .rightShoulder))
        if abs(shoulderCenter.z - hipCenter.z) > 0.12 {
            errors.append(FormError(message: "Прогиб в пояснице, напрягите пресс", severity: .warning))
        }

        return errors
    }
}
